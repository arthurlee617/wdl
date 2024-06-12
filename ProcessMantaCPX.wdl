version 1.0

workflow ProcessMantaCPX {
    input {
        File manta_tarball
        Array[String] pe_file_urls
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
    scatter (pe_file_url in pe_file_urls) {
        call DownloadFiles {
            input:
                file_url = pe_file_url,
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
