
rule cluster_peaks:
    conda:
        '../envs/peakClustering.yml'
    input:
        peak_calls='path/to/peak/calls/dir'
    shell:'''
    perl scripts/footloop.pl -n {input.peak_calls}
    '''