#!/bin/bash

source ~/.bash_profile
source ~/.bashrc

pnpm uninstall -g n8n
npm uninstall -g pnpm

rm -rf /usr/home/$(whoami)/.npm-global
rm -rf /usr/home/$(whoami)/bin
rm -rf /usr/home/$(whoami)/.bash_profile
rm -rf /usr/home/$(whoami)/.bashrc
rm -rf /usr/home/$(whoami)/.local
rm -rf /usr/home/$(whoami)/.npm
rm -rf /usr/home/$(whoami)/.npmrc
rm -rf /usr/home/$(whoami)/.cache
rm -rf /usr/home/$(whoami)/.local/share/pnpm
rm -rf /usr/home/$(whoami)/.npm-global/lib/node_modules/pnpm
rm -rf /usr/home/$(whoami)/n8n
rm -rf /usr/home/$(whoami)/.local/share/pnpm/global/5/node_modules
rm -rf /usr/home/$(whoami)/.local/share/pnpm/global/5/.pnpm
rm -rf /usr/home/$(whoami)/.n8n
rm -rf /usr/home/$(whoami)/n8n-serv00/n8n/

echo "卸载完成"