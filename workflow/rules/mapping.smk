

rule mapping:
    conda:
        '../envs/mapping.yml'
    input:
        # pass
        fastq='path/to/reads',
        genome='path/to/genome/fasta'
    output:
        # pass
    shell:'''
    perl scripts/footloop/footLoop.pl -r {input.fastq} -n {output} -l \
    {params.label} -i {input.index_bed}
    '''

