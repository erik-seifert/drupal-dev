#!/bin/bash

echo "RUN METRICS ON ${DRONE_DIR}/${SRC_DIR}"

phpcs --version
mkdir /results/phpcs
phpcs --standard=Drupal --report=xml --report-file=/results/phpcs/result.xml --extensions=php,module,inc,install,test,profile,theme,js,css,info,txt,md ${DRONE_DIR}

phpmetrics --version
mkdir /results/phpmetrics
phpmetrics --report-html=/results/phpmetrics/result.html ${DRONE_DIR}/${SRC_DIR}

pdepend --version
mkdir /results/pdepend
pdepend --summary-xml=/results/pdepend/result.html ${DRONE_DIR}/${SRC_DIR}

phploc --version
mkdir /results/phploc
phploc ${DRONE_DIR}/${SRC_DIR} > /results/phploc/result.txt

tar -zcvf results.tar.gz /results
mv results.tar.gz /results

exit
