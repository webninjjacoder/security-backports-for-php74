<?php
session_start();
$_SESSION['n'] = ($_SESSION['n'] ?? 0) + 1;
echo json_encode(['n' => $_SESSION['n'], 'id_len' => strlen(session_id())]);
