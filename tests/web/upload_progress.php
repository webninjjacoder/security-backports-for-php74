<?php
echo json_encode(['upload_progress_enabled' => ini_get('session.upload_progress.enabled'),
                  'max_multipart_body_parts' => ini_get('max_multipart_body_parts'),
                  'max_input_vars' => ini_get('max_input_vars')]);
