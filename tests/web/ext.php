<?php
$r = [];
$r['json'] = json_encode(['a' => 1, 'b' => [1, 2]]);
$r['mb'] = mb_strtoupper('ünïcödé');
$r['gd'] = function_exists('imagecreatetruecolor') && imagesx(imagecreatetruecolor(10, 5)) === 10;
$r['curl'] = function_exists('curl_init');
$r['pdo'] = in_array('mysql', PDO::getAvailableDrivers());
$r['redis'] = class_exists('Redis');
$r['soap'] = class_exists('SoapClient');
$r['zip'] = class_exists('ZipArchive');
$r['xml'] = (new DOMDocument())->loadXML('<a><b>1</b></a>');
$r['opcache'] = function_exists('opcache_get_status');
$r['hash'] = hash('sha256', 'x');
$r['serialize'] = unserialize(serialize(['x' => new ArrayObject([1, 2])]))['x']->count();
$r['preg'] = preg_replace('/(\d+)/', '[$1]', 'a1b22');
$r['concat'] = strlen(str_repeat('ab', 50000) . str_repeat('cd', 50000));
$r['big_array'] = count(range(1, 200000));
echo json_encode($r);
