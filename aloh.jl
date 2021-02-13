# TODO:
# - add max storage days
# - add full requirement
# - reTest.jl for tests?

using JuMP
using GLPK

# *** Inputs ***

# order_list is a list of lists, one list for each product
# Orders can be placed on different days. There can be several or no orders on one day.
# Each order is a tuple (day, volume, price).

struct Order
    day:: Int64
    volume:: Int64
    price:: Float64
end

order_list = [
    [(1,  4, 0.5), 
     (1,  1, 0.5), 
     (1,  5, 0.1), # unprofitable, must reject
     (2,  8, 0.5), 
     (3, 14, 0.5)],
    [(1, 12, 0.5), # over capacity, must reject 
     (3, 21, 0.5)]
]
capacity = [10, 10]
unitcost = [0.2, 0.2]
inventory_weight = 0.5

# *** Model ***

function maxday(order_list)
    maximum(item[1] for row in order_list for item in row)
end  

function nrows(order_list)
    size(order_list, 1)
end

n_products = nrows(order_list)
n_days = maxday(order_list)

model = Model(GLPK.Optimizer)

# Production
@variable(model, 0 <= x[p=1:n_products, t=1:n_days] <= capacity[p])

# Costs
costs = unitcost .* x

# Create binary variable for each order, 1 - accept order, 0 - reject order
acc = Vector{Vector{VariableRef}}()
for (i, row) in enumerate(order_list)
    vs = @variable(model, [j=1:length(row)], Bin, base_name="acc_"*string(i))
    push!(acc, vs)    
end  

# Create shipments and sales expressions
ship = @expression(model, [p=1:n_products, t=1:n_days], AffExpr())
sales = @expression(model, [p=1:n_products, t=1:n_days], AffExpr())
for (p, orders) in enumerate(order_list)
  for (j, order) in enumerate(orders)
    t = order[1]
    volume = order[2]
    price = order[3]
    add_to_expression!(ship[p,t], volume, acc[p][j])
    add_to_expression!(sales[p,t], volume * price, acc[p][j])
  end 
end     

# Stocks (Inventory)
function accum(as)
    cumsum(as, dims=2)
end    
cx = accum(x) 
cs = accum(ship)
s = cx .- cs

# Profit
profit = sales - costs 

# Constraint 1: no inventory left on the last day
@constraint(model, s[:,n_days] .== 0)

# Constraint 2: inventory is positive
@constraint(model, s .>= 0)

# Objective function
obj= sum(profit) - sum((inventory_weight * unitcost) .* s)
@objective(model, Max, obj)

optimize!(model)

# *** Output ***

function unpack(acc::Array{Array{VariableRef,1},1})
   [Int.(value.(ac)) for ac in acc]
end

if termination_status(model) == MOI.OPTIMAL
    println("accept = ", unpack(acc))
    println("production = ", value.(x))
    println("ship = ", value.(ship))
    println("inventory = ", value.(s))
else
    println("Solution not found")
end

@assert unpack(acc) == [[1, 1, 0, 1, 1], [0, 1]]
@assert value.(x) ==    [7 10 10; 
                         1 10 10]
@assert value.(ship) == [5  8 14; 
                         0  0 21]
@assert value.(s) ==    [2  4  0; 
                         1 11  0]