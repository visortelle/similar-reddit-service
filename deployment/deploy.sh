#!/usr/bin/env bash

set -eo pipefail

git_branch=$(git rev-parse --abbrev-ref HEAD)

echo "Deploying the current branch \"${git_branch}\" to AWS"

function validate_env() {
	if [[ -z "${VM_SSH_KEY}" ]]; then
		echo "VM_SSH_KEY environment variable is not set"
		exit 1
	fi
}

validate_env

if [[ "${git_branch}" == "develop" ]]; then
	vm_host="ec2-user@ec2-35-170-63-226.compute-1.amazonaws.com"
else
	echo "Not deployment configuration found for branch: ${git_branch}"
	exit 0
fi

echo "Configuring VM SSH key"
mkdir -p ~/.ssh && echo "${VM_SSH_KEY}" >~/.ssh/vm_ssh_key && chmod 600 ~/.ssh/vm_ssh_key

echo "Running deployment commands on VM"

vm_git_root="~/similar-reddit-service"
vm_command_pull_latest_changes="cd $vm_git_root && git reset --hard HEAD && git checkout $git_branch && git pull"
vm_command_restart_docker_compose="cd $vm_git_root/deployment && ./config/populate.sh && docker-compose pull && make restart"
vm_commands="${vm_command_pull_latest_changes} && ${vm_command_restart_docker_compose}"

ssh -i ~/.ssh/vm_ssh_key -o "StrictHostKeyChecking=no" "${vm_host}" "$vm_commands"

function test_deployment() {
	test_url="http://${vm_host}/api/v1/health"

	echo "Awaiting deployment at ${test_url} to be ready"

	curl --fail \
		--retry-all-errors \
		--retry 100 \
		--retry-delay 0 \
		--retry-max-time 120 "${test_url}"

	echo "Deployment is ready at ${vm_host}"
}

test_deployment
