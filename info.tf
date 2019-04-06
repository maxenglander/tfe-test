data "template_file" "tools" {
  template = <<EOF
AWSPATH=""
PIPPATH=""
PYENVPATH=""
WORKDIR="/tmp/${uuid()}"

if ! which aws > /dev/null; then
  if ! which pip > /dev/null; then
    curl https://pyenv.run | bash
    export PATH="/$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"

    if ! pyenv install 3.5.0; then
      python_install_failure=$(pyenv install 3.5.0 2>&1 | tr "\n" ";")
      echo "{\"aws\":\"\",\"failure\":\"$python_install_failure\"}"
      exit
    fi
    pyenv global 3.5.0

    PYENVPATH=$(which pyenv 2> /dev/null)
    PIPPATH=$(pyenv which pip 2> /dev/null)
    PYTHONPATH=$(pyenv which python 2> /dev/null)

    if ! pip show awscli > /dev/null; then
      pip install awscli
      AWSPATH=$(pyenv which awscli 2> /dev/null)
    fi
  else
    pip install awscli
  fi
fi

[ ! -z $AWSPATH ] || AWSPATH=$(which aws 2> /dev/null)
[ ! -z $PIPPATH ] || PIPPATH=$(which pip 2> /dev/null)
[ ! -z $PYTHONPATH ] || PYTHONPATH=$(which python 2> /dev/null)

echo "{\"aws\":\"$AWSPATH\",\"pip\":\"$PIPPATH\",\"pyenv\":\"$PYENVPATH\",\"python\":\"$PYTHONPATH\",\"workdir\":\"$WORKDIR\"}"
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
