version 1.0

workflow ProcessMantaCPX {
    input {
        File manta_tarball
        Array[String] pesr_disc
        File mei_bed
        File cytobands_bed
        String docker_image
    }

    # Download and extract Manta tarball
    call ExtractManta {
        input:
            manta_tarball = manta_tarball,
            docker_image = docker_image
    }

    # Download PE files
    scatter (pesr_disc in pesr_discs) {
        call DownloadFiles {
            input:
                file_url = pesr_disc,
                docker_image = docker_image
        }
    }

    # Run SVTK Resolve
    scatter (vcf_file in ExtractManta.vcf_files) {
        call RunSvtkResolved {
            input:
                vcf_file = vcf_file,
                pe_file = select_first(DownloadFiles.downloaded_files),
                mei_bed = mei_bed,
                cytobands_bed = cytobands_bed,
                docker_image = docker_image
        }

        # Extract complex variants
        call ExtractComplex {
            input:
                unresolved_vcf = RunSvtkResolved.unresolved_vcf,
                docker_image = docker_image
        }
    }

    # Cluster results
    call Cluster {
        input:
            docker_image = docker_image
    }
}

task DownloadFiles {
    input {
        String file_url
        String docker_image
    }

    command {
        gsutil cp ~{file_url} .
    }

    output {
        File downloaded_file = basename(file_url)
    }

    runtime {
        docker: docker_image
    }
}

task ExtractManta {
    input {
        File manta_tarball
        String docker_image
    }

    command {
        tar -xzf ~{manta_tarball}
    }

    output {
        Array[File] vcf_files = glob("*.vcf.gz")
    }

    runtime {
        docker: docker_image
    }
}

task RunSvtkResolved {
    input {
        File vcf_file
        File pesr_disc
        File mei_bed
        File cytobands_bed
        String docker_image
    }

    command {
        bash run_svtk_resolved.sh ~{vcf_file} ~{pesr_disc} ~{basename(pesr_disc, ".pe.txt.gz")} ~{mei_bed} ~{cytobands_bed}
    }

    output {
        File unresolved_vcf = basename(pesr_disc, ".pe.txt.gz") + ".manta.unresolved.vcf.gz"
    }

    runtime {
        docker: docker_image
    }
}
