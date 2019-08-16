FROM nvidia/cuda:10.0-cudnn7-devel-ubuntu16.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
        libjpeg-dev \
        libpng-dev \
        libtbb-dev \
        pkg-config \
        libopenexr-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

#-----------------------------------------------------
# Build CMake
RUN curl -L -O https://github.com/Kitware/CMake/releases/download/v3.12.4/cmake-3.12.4.tar.gz && \
    tar -xvzf cmake-3.12.4.tar.gz && \
    rm cmake-3.12.4.tar.gz && \
    cd cmake-3.12.4 && \
    ./bootstrap && make -j24 && make install -j24

#-----------------------------------------------------
# Upgrade to gcc 7
# https://gist.github.com/jlblancoc/99521194aba975286c80f93e47966dc5
RUN apt-get update && apt-get install -y software-properties-common \
    && add-apt-repository ppa:ubuntu-toolchain-r/test \
    && apt update \
    && apt install g++-7 -y \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 60 \
                           --slave /usr/bin/g++ g++ /usr/bin/g++-7 \
    && update-alternatives --config gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

#-----------------------------------------------------
# Install Miniconda and Python
RUN curl -o ~/miniconda.sh -O  https://repo.anaconda.com/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh   \
    && chmod +x ~/miniconda.sh  \
    && ~/miniconda.sh -b -p /opt/conda  \
    && rm ~/miniconda.sh

ENV PATH /opt/conda/bin:$PATH

RUN conda install -y \
        python=$PYTHON_VERSION \
        pyyaml=5.1 \
        scipy=1.2.1 \
        numpy=1.16.4 \
        ipython=7.5 \
        mkl=2019.4 \
        mkl-include=2019.4 \
        cython=0.29.10 \
        typing=3.6.4 \
        ffmpeg=4.0 \
        scikit-image=0.15.0 \
        pybind11=2.2.4 \
    && pip install ninja==1.9.0.post1 \
    && pip install tensorflow-gpu==1.14.0 \
    && conda install --yes pytorch=1.1.0 torchvision=0.3.0 -c pytorch \
    && /opt/conda/bin/conda clean -ya

#---------------------------------------------------
# Copy Redner app to container
COPY . /app
WORKDIR /app
RUN chmod -R a+w /app

#---------------------------------------------------
# Setup runtime
ARG OPTIX_VERSION=5.1.0
ENV LD_LIBRARY_PATH /usr/local/lib:/app/dockerfiles/dependencies/NVIDIA-OptiX-SDK-${OPTIX_VERSION}-linux64/lib64:${LD_LIBRARY_PATH}


#---------------------------------------------------
# Copy Redner app to container
COPY . /app
WORKDIR /app
RUN chmod -R a+w /app

#-----------------------------------------------------
# Build Redner C++ code
WORKDIR /app
RUN if [ -d "build" ]; then rm -rf build; fi \
    && mkdir build \
    && cd build \
    && cmake .. -DEMBREE_ISPC_SUPPORT=false -DEMBREE_TUTORIALS=false -DOptiX_INSTALL_DIR=/app/dockerfiles/dependencies/NVIDIA-OptiX-SDK-${OPTIX_VERSION}-linux64 \
    && make install -j24 \
    && cd / \
    && rm -rf /app/build/

