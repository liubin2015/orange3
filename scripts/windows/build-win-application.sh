#!/bin/bash -e

# Build an Windows applicaiton installer for Orange Canvas
# (needs makensis and 7z on PATH)
#
# Example:
#
#     $ build-win-application.sh dist/Orange-installer.exe
#

function print_usage {
    echo 'build-win-application.sh
Build an Windows applicaiton installer for Orange Canvas

Note: needs makensis and 7z on PATH

Options:

    -b --build-base PATH    Build directory (default build/win-installer)
    -d --dist-dir           Distribution dir
    -h --help               Print this help
'
}


while [[ ${1:0:1} = "-" ]]; do
    case $1 in
        -b|--build-base)
            BUILDBASE=$2
            shift 2
            ;;
        -d|--dist-dir)
            DISTDIR=$2
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -*)
            echo "Unkown argument $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

PLATTAG=win32

PYTHON_VER=3.4.2
PYTHON_MD5=0aa1a556892d8dc0b60c19bf3102fb3f

PYTHON_VER_SHORT=${PYTHON_VER%.[0-9]*}
PYVER=$(echo $PYTHON_VER_SHORT | sed s/\\.//g)
PYTHON_MSI=python-$PYTHON_VER.msi

PYQT_VER=4.11.3
PYQT_MD5=10f15f41d30152a71590709563499dbe

NUMPY_VER=1.9.1
NUMPY_MD5=1402e7689bebbd7b69630bdcdc58a492

SCIPY_VER=0.15.1
SCIPY_MD5=e24c435e96dc7fbde8eac62ca8c969c8

IPYTHON_VER=2.4.0

MATPLOTLIB_VER=1.4.1

SCIKIT_LEARN_VER=0.15.2

DISTDIR=${DISTDIR:-dist}

BUILDBASE=${BUILDBASE:-build}/temp.$PLATTAG-installer

# BUILDBASE/
#   core/
#     python/
#     msvredist/
#   wheelhouse/
#       [no]sse[2|3]/
#   pyqt4/
#   requirements.txt
#   download/

DOWNLOADDIR="$BUILDBASE"/download

mkdir -p "$BUILDBASE"/core/python
mkdir -p "$BUILDBASE"/core/msvredist
mkdir -p "$BUILDBASE"/wheelhouse
mkdir -p "$BUILDBASE"/pyqt4
mkdir -p "$DOWNLOADDIR"

touch "$BUILDBASE"/requirements.txt

echo "
#:wheel: scikit-learn https://pypi.python.org/packages/3.4/s/scikit-learn/scikit_learn-0.15.2-cp34-none-win32.whl#md5=40552c03c3aed7910d03b5801fbb3f26
scikit-learn==0.15.2

#:wheel: matplotlib https://pypi.python.org/packages/cp34/m/matplotlib/matplotlib-1.4.2-cp34-none-win32.whl#md5=f18b7568493bece5c7b3eb7bb4203826
matplotlib==1.4.2

#:wheel: ipython https://pypi.python.org/packages/3.4/i/ipython/ipython-2.4.1-py3-none-any.whl#md5=7e377fe675a88eb49e720c98de4a7ee4
ipython==2.4.1

#:wheel: pyzmq https://pypi.python.org/packages/3.4/p/pyzmq/pyzmq-14.5.0-cp34-none-win32.whl#md5=333bc2f02d24aa2455ce4208b9d8666e
pyzmq==14.5.0

#:wheel: pygments https://pypi.python.org/packages/3.3/P/Pygments/Pygments-2.0.2-py3-none-any.whl#md5=b38281817abc47c82cf3533b8c6608f6
pygments==2.0.2

#:wheel: networkx https://pypi.python.org/packages/2.7/n/networkx/networkx-1.9.1-py2.py3-none-any.whl#md5=15bb60c9b386563a6d4765264f5bf687
networkx==1.9.1

#:source: decorator
decorator==3.4.0

#:source: sqlparse
sqlparse==0.1.13

#:wheel: Bottlecheset https://dl.dropboxusercontent.com/u/100248799/Bottlechest-0.7.1-cp34-none-win32.whl#md5=629ba2a148dfa784d0e6817497d42e97
Bottlechest==0.7.1

#:source: pyqtgraph
pyqtgraph==0.9.10
" > "$BUILDBASE"/requirements.txt


function __download_url {
    local url=${1:?}
    local out=${2:?}
    curl --fail -L --max-redirs 4 -o "$out" "$url"
}

function md5sum_check {
    local filepath=${1:?}
    local checksum=${2:?}

    if [[ -x $(which md5) ]]; then
        md5=$(md5 -q "$filepath")
    else
        md5=$(md5sum "$filepath" | cut -d " " -f 1)
    fi

    [ "$md5" == "$checksum" ]
}

#
# download_url URL TARGET_PATH MD5_CHECKSUM
#
# download the contants of URL and to TARGET_PATH and check that the
# md5 checksum matches.

function download_url {
    local url=${1:?}
    local targetpath=${2:?}
    local checksum=${3:?}

    if [ -f "$targetpath" ] && ! md5sum_check "$targetpath" "$checksum"; then
        rm "$targetpath"
    fi

    if [ ! -f "$targetpath" ]; then
        __download_url "$url" "$targetpath"
    fi

    if ! md5sum_check "$targetpath" "$checksum"; then
        echo "Checksum does not match for $OUT"
        exit 1
    fi
}

#
# Download python msi installer
#
function prepare_python {
    local url="https://www.python.org/ftp/python/$PYTHON_VER/$PYTHON_MSI"
    download_url "$url" "$DOWNLOADDIR/$PYTHON_MSI" $PYTHON_MD5
    cp "$DOWNLOADDIR/$PYTHON_MSI" "$BUILDBASE"/core/python
}

function prepare_msvredist {
    local url="https:/orange.biolab.si/files/3rd-party/$PYVER/vcredist_x86.exe"
    download_url $url \
                 "$BUILDBASE/core/msvredist/vcredist_x86.exe" \
                 b88228d5fef4b6dc019d69d4471f23ec
}

function prepare_pyqt4 {
    local filename=PyQt4-${PYQT_VER}-gpl-Py${PYTHON_VER_SHORT}-Qt4.8.6-x32.exe
    local url="http://sourceforge.net/projects/pyqt/files/PyQt4/PyQt-${PYQT_VER}/$filename"
    local installer="$DOWNLOADDIR"/$filename
    local extractdir="$DOWNLOADDIR/PyQt4_extr"
	local pyqtdir="$BUILDBASE"/pyqt4

    download_url "$url" "$installer" $PYQT_MD5

    7z -o"$extractdir" -y x "$installer"

    if [[ -d "$pyqtdir" ]]; then
        rm -r "$pyqtdir"
    fi
    mkdir -p "$pyqtdir"

    cp -a -f "$extractdir"/Lib/site-packages/* "$pyqtdir"/

	if [[ -d "$extractdir"/'$_OUTDIR' ]]; then
		# * .pyd, doc/, examples/, mkspecs/, qsci/, include/, uic/
		cp -a -f "$extractdir"/'$_OUTDIR'/*.pyd "$pyqtdir"/PyQt4
        cp -a -f "$extractdir"/'$_OUTDIR'/uic "$pyqtdir"/PyQt4/
        # ignore the rest
	fi
    echo '[PATHS]' > "$pyqtdir"/PyQt4/qt.conf
    echo 'Prefix = .' >> "$pyqtdir"/PyQt4/qt.conf
}

function prepare_scipy_stack {
	local numpy_superpack=numpy-$NUMPY_VER-win32-superpack-python$PYTHON_VER_SHORT.exe
	local scipy_superpack=scipy-$SCIPY_VER-win32-superpack-python$PYTHON_VER_SHORT.exe

    download_url http://sourceforge.net/projects/numpy/files/NumPy/$NUMPY_VER/$numpy_superpack/download \
                 "$DOWNLOADDIR"/$numpy_superpack \
                 $NUMPY_MD5

    download_url http://sourceforge.net/projects/scipy/files/scipy/$SCIPY_VER/$scipy_superpack/download \
                 "$DOWNLOADDIR"/$scipy_superpack \
                 $SCIPY_MD5

    7z -o"$DOWNLOADDIR"/numpy -y e "$DOWNLOADDIR"/$numpy_superpack
    7z -o"$DOWNLOADDIR"/scipy -y e "$DOWNLOADDIR"/$scipy_superpack

	local wheeltag=cp${PYVER}-none-win32
	local wheeldir=

    for SSE in nosse sse2 sse3; do
		wheeldir="$BUILDBASE"/wheelhouse/$SSE
        mkdir -p "$wheeldir"

        python -m wheel convert -d "$wheeldir" \
               "$DOWNLOADDIR"/numpy/numpy-$NUMPY_VER-$SSE.exe

        mv "$wheeldir"/numpy-$NUMPY_VER-*$SSE.whl \
		   "$wheeldir"/numpy-$NUMPY_VER-$wheeltag.whl

        python -m wheel convert -d "$wheeldir" \
			   "$DOWNLOADDIR"/scipy/scipy-$SCIPY_VER-$SSE.exe

        mv "$wheeldir"/scipy-$SCIPY_VER-*$SSE.whl \
		   "$wheeldir"/scipy-$SCIPY_VER-$wheeltag.whl
    done

}


function prepare_req {
    python -m pip wheel \
        -w "$BUILDBASE/wheelhouse" \
        -f "$BUILDBASE/wheelhouse" \
        -f "$BUILDBASE/wheelhouse/nosse" \
        "$@"
}


function prepare_orange {
    python setup.py egg_info
    local version=$(grep -E "^Version: .*$" Orange.egg-info/PKG-INFO | awk '{ print $2 }')

    python setup.py egg_info \
        build --compiler=msvc \
        bdist_wheel -d "$BUILDBASE/wheelhouse"

    echo "# Orange " >> "$BUILDBASE/requirements.txt"
    echo "Orange==$version" >> "$BUILDBASE/requirements.txt"
}


function prepare_all {
    prepare_python
    prepare_scipy_stack
    prepare_pyqt4
    prepare_req -r "$BUILDBASE/requirements.txt"
    prepare_orange
}




function abs_dir_path {
    echo $(cd "$1"; pwd)
}

function create_installer {
    local basedir=${1:?}
    local installer_path=${2:?}
    local basedir_abs=$(cd "$basedir"; pwd)

    if [[ ${installer_path:0:1} != "/" ]]; then
        installer_path="$(pwd)/$installer_path"
    fi

    makensis -DOUTFILENAME="$installer_path" \
             -DPYTHON_VERSION=$PYTHON_VER \
             -DPYVER=$PYTHON_VER_SHORT \
			 -DBASEDIR="$basedir_abs" \
             scripts/windows/install.nsi
}

function install_all {
    install_python
    install_pip
    install_scipy_stack
    install_ipython
    install_matplotlib
}

# Prepare prerequisites
prepare_all

VERSION=$(grep -E "^Orange==" "$BUILDBASE/requirements.txt" | sed s/^Orange==//g)

# Package everything in an installer
create_installer "$BUILDBASE" \
    "$DISTDIR"/Orange3-${VERSION:?}.$PLATTAG-py$PYTHON_VER_SHORT-install.exe
