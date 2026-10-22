<?php
ini_set('memory_limit', '32M');
$a = [];
while (true) { $a[] = str_repeat('x', 1024 * 1024); }
