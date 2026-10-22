<?php
// echoes what PHP parsed from the request, as stable JSON
$files = [];
foreach ($_FILES as $k => $f) {
    $files[$k] = is_array($f['name'])
        ? ['name' => $f['name'], 'size' => $f['size'], 'error' => $f['error']]
        : ['name' => $f['name'], 'size' => $f['size'], 'error' => $f['error'], 'md5' => $f['error'] ? null : md5_file($f['tmp_name'])];
}
header('Content-Type: application/json');
echo json_encode([
    'get' => $_GET, 'post' => $_POST, 'cookie' => $_COOKIE, 'files' => $files,
    'auth' => [$_SERVER['PHP_AUTH_USER'] ?? null, $_SERVER['PHP_AUTH_PW'] ?? null],
    'ctype' => $_SERVER['CONTENT_TYPE'] ?? null,
]);
