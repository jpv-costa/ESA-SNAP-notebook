ARG BASE_CONTAINER=jupyter/tensorflow-notebook:bbf0ada0a935
FROM $BASE_CONTAINER

# Set jupyter default memory usage limit to 6GB (in bytes)
ARG MEM_LIMIT=6442450944
# Set jupyter default cpu usage limit to 6 cores
ARG CPU_LIMIT=6
# Set name of the default conda environment
#ARG conda_env=python38
#ARG py_ver=3.8

USER root
ADD "snap-demo.ipynb" $HOME
RUN echo "c.ResourceUseDisplay.track_cpu_percent = True" >> /etc/jupyter/jupyter_notebook_config.py && \
    echo "c.ResourceUseDisplay.cpu_limit = ${CPU_LIMIT}" >> /etc/jupyter/jupyter_notebook_config.py && \
    cd $HOME && \
    echo $PWD && \    
    fix-permissions snap-demo.ipynb

COPY --chown=${NB_UID}:${NB_GID} requirements.txt ./

RUN apt-get update -y && \
    # Install Proj4 and geo, which are depencies required by cartopy
    apt-get install -y libproj-dev proj-data proj-bin && \
    apt-get install -y libgeos-dev && \
    apt-get install -y libgdal-dev && \
    apt-get install -y --no-install-recommends \
    software-properties-common=* && \
    add-apt-repository ppa:deadsnakes/ppa

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID

ENV SITE_PACKAGES=$CONDA_DIR/envs/$conda_env/lib/python3.8/site-packages \
    SNAP_HOME=$CONDA_DIR/envs/$conda_env/snap

RUN conda config --append channels terradue && \
    conda config --append channels defaults && \
    conda list -e > conda_requirements.txt && \
    echo $' \n\
    ipython=7.23.0 \n\
    ipykernel=5.5.3 \n\
    java-1.7.0-openjdk-cos6-x86_64=1.7.0.131 \n\
    jpy=0.9.0 \n\
    snap=8.0.0=py38_2 \n\
    jupyter-resource-usage=0.6.0' >> conda_requirements.txt && \
    conda create --yes -p $CONDA_DIR/envs/$conda_env python=$py_ver --file conda_requirements.txt && \
    # Install snappy package
    cd /opt/conda/envs/$conda_env/bin/ && \
    ./python $SNAP_HOME/.snap/snap-python/snappy/setup.py install && \
    # Rename package to snappy_esa to avoid conflicts with google's snappy package
    mv $SITE_PACKAGES/snappy $SITE_PACKAGES/snappy_esa && \
    mv $SITE_PACKAGES/snappy_esa/snappy.ini $SITE_PACKAGES/snappy_esa/snappy_esa.ini && \
    # Install python packages from the requirements file    
    ./pip install --no-cache-dir -r requirements.txt && \   
    # create Python 3.x environment and link it to jupyter
    ./python -m ipykernel install --user --name=${conda_env} && \
    $SNAP_HOME/bin/snap --nosplash --nogui --modules --install org.esa.snap.idepix.core && \
    $SNAP_HOME/bin/snap --nosplash --nogui --modules --install org.esa.snap.idepix.olci && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    conda clean --all -f -y

# Enable jupyterlab
ENV JUPYTER_ENABLE_LAB=TRUE \
    # Set memory usage limit
    MEM_LIMIT=${MEM_LIMIT} \    
    GPT_BIN=$SNAP_HOME/bin/gpt
