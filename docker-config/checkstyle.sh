#!/bin/bash
mkdir /results/phpcs
phpcs --standard=Drupal --report=xml --report-file=/results/phpcs/result.xml --extensions=php,module,inc,install,test,profile,theme,js,css,info,txt,md ${DRONE_DIR}

mkdir /results/phpmetrics
phpmetrics --report-html=/results/phpmetrics/result.html ${DRONE_DIR}
