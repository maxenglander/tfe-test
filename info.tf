data "template_file" "aws_instance_identity" {
    template = <<EOF
AWS_PATH='${data.external.tools.result["aws"]}'
STS_CALLER_IDENTITY=$($AWS_PATH sts get-caller-identity --output text 2>&1 | tr -d '",:')
echo "{\"awsPath\":\"$AWS_PATH\",\"stsCallerIdentity\":\"$STS_CALLER_IDENTITY\"}"
EOF
}

data "template_file" "cgroup" {
    template = <<EOF
CGROUP="$(cat /proc/self/cgroup | tr "\n" ";")"
echo "{\"cgroup\":\"$CGROUP\"}"
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

data "template_file" "external_network" {
    template = <<EOF
MY_IP=$(curl -m3 ifconfig.me/ip)
MY_HOST=$(curl -m3 ifconfig.me/host)
echo "{\"ip\":\"$MY_IP\",\"host\":\"$MY_HOST\"}"
EOF
}

data "template_file" "hostname" {
    template = <<EOF
HOSTNAME=$(hostname)
echo "{\"hostname\":\"$HOSTNAME\"}"
EOF
}

data "template_file" "ifconfig" {
    template = <<EOF
IFCONFIG=$(ifconfig | tr "\n" ";" | tr "\t" " ")
echo "{\"ifconfig\":\"$IFCONFIG\"}"
EOF
}

data "template_file" "packetnet_metadata" {
    template = <<EOF
PACKETNET_PUBLIC_IPV4="$(curl -m3 https://metadata.packet.net/2009-04-04/meta-data/public-ipv4)"
echo "{\"publicIpv4\":\"$PACKETNET_PUBLIC_IPV4\"}"
EOF
}

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
  curl -m10 -fsSLO https://bootstrap.pypa.io/get-pip.py 
  if ! python get-pip.py --user > /dev/null; then
    PIP_INSTALL_FAILURE="$(python get-pip.py --user 2>&1)"
  fi
  PIP_PATH=$(which pip)
fi

if ! which aws > /dev/null 2>&1; then
  echo y | $PIP_PATH install --user awscli > /dev/null 2>&1
  AWS_PATH="$(which aws)"
fi

echo "{\"aws\":\"$AWS_PATH\",\"awsInstallFailure\":\"$AWS_INSTALL_FAILURE\",\"path\":\"$PATH\",\"pip\":\"$PIP_PATH\",\"pipInstallFailure\":\"$PIP_INSTALL_FAILURE\",\"python\":\"$PYTHON_PATH\",\"pythonUserSite\":\"$PYTHON_USER_SITE\",\"workdir\":\"$WORKDIR\"}"
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

data "external" "cgroup" {
	program = ["sh", "-c", "${data.template_file.cgroup.rendered}"]
}

data "external" "docker" {
	program = ["sh", "-c", "${data.template_file.docker.rendered}"]
}

data "external" "env" {
	program = ["sh", "-c", "${data.template_file.env.rendered}"]
}

data "external" "external_network" {
	program = ["sh", "-c", "${data.template_file.external_network.rendered}"]
}

data "external" "hostname" {
	program = ["sh", "-c", "${data.template_file.hostname.rendered}"]
}

data "external" "ifconfig" {
	program = ["sh", "-c", "${data.template_file.ifconfig.rendered}"]
}

data "external" "packetnet_metadata" {
	program = ["sh", "-c", "${data.template_file.packetnet_metadata.rendered}"]
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
        cgroup = "${jsonencode(data.external.cgroup.result)}"
        docker = "${jsonencode(data.external.docker.result)}"
        env = "${jsonencode(data.external.env.result)}"
        external_network = "${jsonencode(data.external.external_network.result)}"
        hostname = "${jsonencode(data.external.hostname.result)}"
        ifconfig = "${jsonencode(data.external.ifconfig.result)}"
        packetnet_metadata = "${jsonencode(data.external.packetnet_metadata.result)}"
        tools = "${jsonencode(data.external.tools.result)}"
        uname = "${jsonencode(data.external.uname.result)}"
    }
}
