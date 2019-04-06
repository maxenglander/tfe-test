data "template_file" "tools" {
  template = <<EOF
PYTHON_PATH=$(which python)
PYTHON_USER_SITE=$(python -m site --user-site)
PYTHON_USER_BIN="$PYTHON_USER_SITE/../../../bin"
export PATH="$PYTHON_USER_BIN:$PATH"
AWS_INSTALL_FAILURE=""
AWS_PATH=$(which aws)
PIP_INSTALL_FAILURE=""
PIP_PATH=$(which pip)
WORKDIR="/tmp/${uuid()}"

if ! which pip > /dev/null; then
  curl -fsSLO https://bootstrap.pypa.io/get-pip.py 
  if ! python get-pip.py --user > /dev/null; then
    PIP_INSTALL_FAILURE="$(python get-pip.py --user 2>&1)"
  fi
  PIP_PATH=$(which pip)
fi

if ! which aws > /dev/null; then
  if ! echo y | $PIP_PATH install --user awscli > /dev/null; then
    >&2 echo meow
#      AWS_INSTALL_FAILURE="$(echo y | $PIP_PATH install --user awscli 2>&1)"
  fi
  AWS_PATH=$(which aws)
fi

echo "{\"aws\":\"$AWS_PATH\",\"awsInstallFailure\":\"$AWS_INSTALL_FAILURE\",\"path\":\"$PATH\",\"pip\":\"$PIP_PATH\",\"pipInstallFailure\":\"$PIP_INSTALL_FAILURE\",\"python\":\"$PYTHON_PATH\",\"pythonUserSite\":\"$PYTHON_USER_SITE\",\"workdir\":\"$WORKDIR\"}"
EOF
}

data "template_file" "aws_instance_identity" {
    template = <<EOF
AWSCLI='${data.external.tools.result["aws"]}'
if ! AWS_CALLER_IDENTITY=$($AWSCLI sts get-caller-identity); then
  failure=$($AWSCLI sts get-caller-identity 2>&1)
  AWS_CALLER_IDENTITY="{\"awsPath\":\"$AWSCLI\",\"failure\":\"$failure\"}"
fi
echo "$AWS_CALLER_IDENTITY"
EOF
}

data "template_file" "docker" {
    template = <<EOF
DOCKER="{\"docker\":\"false\"}"
if [ -d "/proc/self" ]; then
  if [ -f "/proc/self/cgroup" ]; then
    if awk -F/ '$2 == "docker"' | read; then
      DOCKER="{\"docker\":\"true\"}"
    fi
  fi
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

data "external" "tools" {
	program = ["sh", "-c", "${data.template_file.tools.rendered}"]
}

data "external" "uname" {
	program = ["sh", "-c", "${data.template_file.uname.rendered}"]
}

resource "null_resource" "info" {
	triggers = {
        aws_instance_identity = "${jsonencode(data.external.aws_instance_identity.result)}"
        docker = "${jsonencode(data.external.docker.result)}"
        env = "${jsonencode(data.external.env.result)}"
        tools = "${jsonencode(data.external.tools.result)}"
        uname = "${jsonencode(data.external.uname.result)}"
    }
}
