#!/bin/bash

set -e

UNAMESTR=`uname`

if [[ "$UNAMESTR" == "Darwin" ]]; then
    # install OpenMP not present by default on osx
    HOMEBREW_NO_AUTO_UPDATE=1 brew install libomp

    # enable OpenMP support for Apple-clang
    export CC=/usr/bin/clang
    export CXX=/usr/bin/clang++
    export CPPFLAGS="$CPPFLAGS -Xpreprocessor -fopenmp"
    export CFLAGS="$CFLAGS -I/usr/local/opt/libomp/include"
    export CXXFLAGS="$CXXFLAGS -I/usr/local/opt/libomp/include"
    export LDFLAGS="$LDFLAGS -L/usr/local/opt/libomp/lib -lomp"
    export DYLD_LIBRARY_PATH=/usr/local/opt/libomp/lib
fi

make_conda() {
    TO_INSTALL="$@"
    conda create -n $VIRTUALENV --yes $TO_INSTALL
    source activate $VIRTUALENV
}

version_ge() {
    # The two version numbers are seperated with a new line is piped to sort
    # -rV. The -V activates for version number sorting and -r sorts in
    # decending order. If the first argument is the top element of the sort, it
    # is greater than or equal to the second argument.
    test "$(printf "${1}\n${2}" | sort -rV | head -n 1)" == "$1"
}

if [[ "$DISTRIB" == "conda" ]]; then

    # TODO
    # Remove when wheel issue is fixed with conda installations of python 3.7.4
    if [[ "$PYTHON_VERSION" == "*" ]]; then
        PINNED_PYTHON_VERSION="3.7.3"
    else
        PINNED_PYTHON_VERSION=$PYTHON_VERSION
    fi

    TO_INSTALL="python=$PINNED_PYTHON_VERSION pip pytest=$PYTEST_VERSION \
                pytest-cov numpy=$NUMPY_VERSION scipy=$SCIPY_VERSION \
                cython=$CYTHON_VERSION joblib=$JOBLIB_VERSION"

    if [[ "$INSTALL_MKL" == "true" ]]; then
        TO_INSTALL="$TO_INSTALL mkl"
    else
        TO_INSTALL="$TO_INSTALL nomkl"
    fi

    if [[ -n "$PANDAS_VERSION" ]]; then
        TO_INSTALL="$TO_INSTALL pandas=$PANDAS_VERSION"
    fi

    if [[ -n "$PYAMG_VERSION" ]]; then
        TO_INSTALL="$TO_INSTALL pyamg=$PYAMG_VERSION"
    fi

    if [[ -n "$PILLOW_VERSION" ]]; then
        TO_INSTALL="$TO_INSTALL pillow=$PILLOW_VERSION"
    fi

    if [[ -n "$MATPLOTLIB_VERSION" ]]; then
        TO_INSTALL="$TO_INSTALL matplotlib=$MATPLOTLIB_VERSION"
    fi

    # Old packages coming from the 'free' conda channel have been removed but
    # we are using them for testing Python 3.5. See
    # https://www.anaconda.com/why-we-removed-the-free-channel-in-conda-4-7/
    # for more details. restore_free_channel is defined starting from conda 4.7
    conda_version=$(conda -V | awk '{print $2}')
    if version_ge "$conda_version" "4.7.0" && [[ "$PYTHON_VERSION" == "3.5" ]]; then
        conda config --set restore_free_channel true
    fi

	make_conda $TO_INSTALL
    if [[ "$PYTHON_VERSION" == "*" ]]; then
        pip install pytest-xdist
    fi

elif [[ "$DISTRIB" == "ubuntu" ]]; then
    sudo add-apt-repository --remove ppa:ubuntu-toolchain-r/test
    sudo apt-get install python3-scipy python3-matplotlib libatlas3-base libatlas-base-dev libatlas-dev python3-virtualenv
    python3 -m virtualenv --system-site-packages --python=python3 $VIRTUALENV
    source $VIRTUALENV/bin/activate
    python -m pip install pytest==$PYTEST_VERSION pytest-cov cython joblib==$JOBLIB_VERSION
    # We run a memory profiling test that uses `psutil`. Because it's slow,
    # we only run it on Ubuntu.
    python -m pip install psutil
elif [[ "$DISTRIB" == "ubuntu-32" ]]; then
    apt-get update
    apt-get install -y python3-dev python3-scipy python3-matplotlib libatlas3-base libatlas-base-dev libatlas-dev python3-virtualenv
    python3 -m virtualenv --system-site-packages --python=python3 $VIRTUALENV
    source $VIRTUALENV/bin/activate
    python -m pip install pytest==$PYTEST_VERSION pytest-cov cython joblib==$JOBLIB_VERSION
fi

if [[ "$COVERAGE" == "true" ]]; then
    python -m pip install coverage codecov
fi

if [[ "$TEST_DOCSTRINGS" == "true" ]]; then
    python -m pip install sphinx numpydoc  # numpydoc requires sphinx
fi

python --version
python -c "import numpy; print('numpy %s' % numpy.__version__)"
python -c "import scipy; print('scipy %s' % scipy.__version__)"
python -c "\
try:
    import pandas
    print('pandas %s' % pandas.__version__)
except ImportError:
    print('pandas not installed')
"
pip list
python setup.py build_ext --inplace -j 3
python setup.py develop
