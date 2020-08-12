FROM ubuntu:20.04

LABEL maintainer "Paul Stey <paul_stey@brown.edu>"
LABEL image jh_sandbox
LABEL tag 0.1.1

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y && apt-get upgrade -y
RUN apt install -y \
	sudo \
	wget 

RUN apt-get update && apt-get install -y \
	vim \
	emacs \
    git

RUN adduser ccv
RUN usermod -aG sudo ccv
USER ccv

RUN cd /home/ccv \
    && wget https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh \
    && bash Anaconda3-2020.02-Linux-x86_64.sh -b \
    && rm Anaconda3-2020.02-Linux-x86_64.sh

ENV PATH="/home/ccv/anaconda3/bin:${PATH}"

WORKDIR /home/ccv 

CMD bash
