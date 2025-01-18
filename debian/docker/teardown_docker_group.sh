#!/bin/bash
set -e

# Remove user from docker group
sudo deluser "$USER" docker

# Delete docker group
sudo delgroup docker

# List groups
groups
