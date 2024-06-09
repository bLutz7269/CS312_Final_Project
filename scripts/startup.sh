#!/bin/bash
sudo yum update -y
sudo yum install -y java

mkdir minecraft
cd minecraft
sudo wget "https://piston-data.mojang.com/v1/objects/c9df48efed58511cdd0213c56b9013a7b5c9ac1f/server.jar" -O server.jar
sudo echo "eula=true" > eula.txt

