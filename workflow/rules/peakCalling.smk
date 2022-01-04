
rule peak_calling:
    conda:
        '../envs/peakCalling.yml'
    input:
        mapped_reads_dir='path/to/mapped/reads/dir'
    output:
        'output/dir'
    shell:'''
    perl scripts/footLoop/footPeak.pl -n {input.mapped_reads_dir} -o {output}
    '''

