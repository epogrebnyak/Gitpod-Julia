FROM gitpod/workspace-full

USER gitpod

# Install Julia
RUN sudo apt-get update
RUN sudo apt-get install -y \
        build-essential \
        libatomic1 \
        python \
        gfortran \
        perl \
        wget \
        m4 \
        cmake \
        pkg-config \
#        julia \
RUN  sudo rm -rf /var/lib/apt/lists/*
RUN wget https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.3-linux-x86_64.tar.gz
RUN tar zxvf julia-1.5.3-linux-x86_64.tar.gz

# Give control back to Gitpod Layer
USER root