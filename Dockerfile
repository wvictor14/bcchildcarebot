FROM rocker/r-base:lastet
RUN  install2r rtoot rtweet purrr
COPY . /usr/local/src/myscripts
WORKDIR /usr/local/src/myscripts
CMD ["Rscript", "myscript.R"]