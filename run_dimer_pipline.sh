#!/bin/bash
# Yinying create this by following the instruction writen by SO
# http://gremlin.bakerlab.org/cplx_faq.php
# https://github.com/sokrypton/GREMLIN

# make it stop if error occurs.
# set -e

usage() {
      echo ""
        echo "Usage: $0<OPTIONS>"
        echo "Required Parameters:"
        echo "      -i       <input paired msa> "
        echo "      -f       <fasta for sequence 1> "
        echo "Optional Parameters:"
        echo "      -d       <workdir> "
        echo "      -a       <jobname> "
        echo "      -r       <GREMLIN_ITERATION> "
        echo "      -m       <MATLAB_Compiler_Runtime> "
        echo "      -g       <GREMLIN_DIR> "
        echo "      -s       <GREMLIN_SCRIPT_DIR> "
        echo ""
        exit 1
    }
while getopts ":i:f:d:a:r:m:g:s:" opt; do
    case "${opt}" in
        # required options
        i) msa_path=$OPTARG ;;
        f) fasta_1_path=$OPTARG ;;
        # updatable options
        d) workdir=$OPTARG ;;
        a) jobname=$OPTARG ;;
        r) GREMLIN_ITER+=$OPTARG ;;
        m) MCR_DIR=$OPTARG ;;
        g) GREMLIN_DIR=$OPTARG ;;
        s) GREMLIN_SCRIPT_DIR=$OPTARG ;;
        *) echo Unknown option!;usage ;;
    esac
done

# check required input
if [[ "$msa_path" == "" || "$fasta_1_path" == "" ]];then
    usage
fi

if [[ "$workdir" == "" ]];then
    workdir=.
fi

# REPO/SCRIPTS
if [[ "$GREMLIN_DIR" == "" ]];then
    GREMLIN_DIR=/repo/GREMLIN/
fi

if [[ "$GREMLIN_SCRIPT_DIR" == "" ]];then
    GREMLIN_SCRIPT_DIR=/software/GREMLIN_SCRIPT/
fi

if [[ "$MCR_DIR" == "" ]];then
    MCR_DIR=/usr/local/MATLAB/MATLAB_Compiler_Runtime/v717/
fi

# OTHER PARAMETERS
if [[ "$GREMLIN_ITER" == "" ]];then
    GREMLIN_ITER=30
fi

# Functions Used
# adapted from FoldDock
SeqLen(){

	local A=$(grep -v \> $1 | wc -c)
	local B=$(grep -v \> $1 | wc -l)
	local C=$(($A-$B))
	echo $C
#	return $C
}

mkdir -p ${workdir} || echo NEVER MIND.
mkdir logs || echo NEVER MIND.
pushd ${workdir}

msa_path=$(readlink -f $msa_path)
msa_fn=$(basename $msa_path)
msa_suffix=$(echo "$msa_fn" | awk -F . '{print $NF}')
msa_stem=${msa_fn%."$(echo $msa_suffix)"}

if [[ "$jobname" == "" ]];then
    jobname=$msa_stem
fi

# test msa data
cp $msa_path .

# passing a msa filter
log1=${workdir}/logs/${jobname}_seq_len.log
cmd="$GREMLIN_SCRIPT_DIR/seq_len.pl -i ${msa_fn} -percent 25"
echo "$cmd"
eval "$cmd" 2> ${log1}

# read useful number from log1
seq_len=$(tail -1 ${log1} |awk '{print $NF}')


for i in $GREMLIN_ITER;
do
    # run gremlin
    # takes tooooo loonnnnnnnnng for gremlin in matlab w/ single core, this should be replaced by GREMLIN_TF if possible
    log2=${workdir}/logs/${jobname}_${i}_gremlin_matlab.log
    cmd="$GREMLIN_DIR/run_gremlin.sh $MCR_DIR  ${msa_stem}.cut.msa ${msa_stem}_${i}.mtx MaxIter ${i} verbose 1 apc 0"
    echo "$cmd"
    eval "$cmd" >${log2} 2>&1

    # generate matrix

    log3=${workdir}/logs/${jobname}_${i}_mtx2sco.log
    cmd="$GREMLIN_SCRIPT_DIR/mtx2sco.pl -mtx ${msa_stem}_${i}.mtx -cut ${msa_stem}.cut -div $(SeqLen ${fasta_1_path}) -seq_len ${seq_len} -apcd ${jobname}_${i}.apcd"
    echo "$cmd"
    eval "$cmd" > ${log3} 2>&1

done
popd
