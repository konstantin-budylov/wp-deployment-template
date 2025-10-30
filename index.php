<?php
// PHP Information Page
// This file displays comprehensive PHP configuration and environment details

// Redis Connection Test (via TCP socket)
$redisStatus = [
    'connected' => false,
    'error' => null,
    'version' => null,
    'info' => []
];

try {
    // Set shorter timeout for Redis connection
    $context = stream_context_create([
        'socket' => [
            'connect_timeout' => 2,
            'read_timeout' => 2
        ]
    ]);
    
    $redisHost = getenv('REDIS_HOST') ?: 'redis';
    $redisPort = getenv('REDIS_PORT') ?: '6379';
    
    // Try to connect via TCP socket with timeout
    $redisSocket = @stream_socket_client("tcp://$redisHost:$redisPort", $errno, $errstr, 2, STREAM_CLIENT_CONNECT, $context);
    
    if ($redisSocket) {
        $redisStatus['connected'] = true;
        
        // Send PING command
        @fwrite($redisSocket, "PING\r\n");
        $response = @fread($redisSocket, 512);
        
        if ($response === false) {
            $redisStatus['error'] = 'Failed to read from Redis';
        } else {
            // Try to get version via INFO command
            @fwrite($redisSocket, "INFO server\r\n");
            stream_set_timeout($redisSocket, 2);
            
            $info = '';
            $timeout = microtime(true) + 2;
            while (!feof($redisSocket) && microtime(true) < $timeout) {
                $chunk = @fread($redisSocket, 1024);
                if ($chunk === false) break;
                $info .= $chunk;
            }
            
            // Parse version from INFO
            if (preg_match('/redis_version:(\S+)/', $info, $matches)) {
                $redisStatus['version'] = $matches[1];
            }
            
            if (preg_match('/db0:keys=(\d+)/', $info, $matches)) {
                $redisStatus['info']['keys'] = $matches[1];
            }
        }
        
        @fclose($redisSocket);
    } else {
        $redisStatus['error'] = $errstr ?: 'Could not connect to Redis';
    }
} catch (Exception $e) {
    $redisStatus['error'] = $e->getMessage();
}

// MySQL Connection Test
$mysqlStatus = [
    'connected' => false,
    'error' => null,
    'version' => null,
    'databases' => []
];

try {
    // Read MySQL credentials from environment variables with fallbacks
    $mysqlHost = getenv('MYSQL_HOST') ?: 'mysql';
    $mysqlPort = getenv('MYSQL_PORT') ?: '3306';
    $mysqlUser = getenv('MYSQL_USER') ?: 'test';
    $mysqlPassword = getenv('MYSQL_PASSWORD') ?: (getenv('MYSQL_PASSWORD') ?: 'test123');
    $mysqlDatabase = getenv('MYSQL_DATABASE') ?: 'test'; // Use test database
    
    // Attempt connection (connect without database first to show all databases)
    $mysqli = new mysqli($mysqlHost, $mysqlUser, $mysqlPassword, '', $mysqlPort);
    
    if (!$mysqli->connect_error) {
        $mysqlStatus['connected'] = true;
        $mysqlStatus['version'] = $mysqli->server_info;
        
        // Get list of databases
        $result = $mysqli->query("SHOW DATABASES");
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                $mysqlStatus['databases'][] = $row['Database'];
            }
            $result->free();
        }
        $mysqli->close();
    } else {
        $mysqlStatus['error'] = $mysqli->connect_error;
    }
} catch (Exception $e) {
    $mysqlStatus['error'] = $e->getMessage();
}

// PostgreSQL Connection Test
$postgresStatus = [
    'connected' => false,
    'error' => null,
    'version' => null,
    'databases' => []
];

try {
    // Read PostgreSQL credentials from environment variables with fallbacks
    $pgHost = getenv('POSTGRES_HOST') ?: 'postgresql';
    $pgPort = getenv('POSTGRES_PORT') ?: '5432';
    $pgUser = getenv('POSTGRES_USER') ?: 'postgres';
    $pgPassword = getenv('POSTGRES_PASSWORD') ?: 'password';
    $pgDatabase = getenv('POSTGRES_DB') ?: 'test';
    
    // Try to connect to PostgreSQL
    $pgConnectionString = "host=$pgHost port=$pgPort user=$pgUser password=$pgPassword dbname=$pgDatabase";
    $pgConn = @pg_connect($pgConnectionString);
    
    if ($pgConn) {
        $postgresStatus['connected'] = true;
        $postgresStatus['connection_string'] = "host=$pgHost port=$pgPort user=$pgUser password=*** dbname=$pgDatabase";
        
        // Get PostgreSQL version
        $versionResult = @pg_query($pgConn, "SELECT version()");
        if ($versionResult) {
            $row = pg_fetch_row($versionResult);
            if ($row) {
                // Extract version number from version string
                if (preg_match('/PostgreSQL (\d+\.\d+)/', $row[0], $matches)) {
                    $postgresStatus['version'] = $matches[1];
                }
            }
            pg_free_result($versionResult);
        }
        
        // Get list of databases
        $dbResult = @pg_query($pgConn, "SELECT datname FROM pg_database WHERE datistemplate = false");
        if ($dbResult) {
            while ($dbRow = pg_fetch_assoc($dbResult)) {
                $postgresStatus['databases'][] = $dbRow['datname'];
            }
            pg_free_result($dbResult);
        }
        
        @pg_close($pgConn);
    } else {
        $lastError = @pg_last_error();
        $postgresStatus['error'] = 'Could not connect to PostgreSQL' . ($lastError ? ": $lastError" : '');
        $postgresStatus['connection_string'] = "host=$pgHost port=$pgPort user=$pgUser password=*** dbname=$pgDatabase";
        $postgresStatus['debug_info'] = [
            'host' => $pgHost,
            'port' => $pgPort,
            'user' => $pgUser,
            'database' => $pgDatabase,
            'env_USER' => getenv('POSTGRES_USER'),
            'env_DB' => getenv('POSTGRES_DB')
        ];
    }
} catch (Exception $e) {
    $postgresStatus['error'] = $e->getMessage();
    $postgresStatus['debug_info'] = ['exception' => $e->getTraceAsString()];
}

// RabbitMQ Connection Test (via TCP socket)
$rabbitmqStatus = [
    'connected' => false,
    'error' => null,
    'management_url' => null
];

try {
    $rabbitmqHost = getenv('RABBITMQ_HOST') ?: 'rabbitmq';
    $rabbitmqPort = getenv('RABBITMQ_PORT') ?: '5672';
    $rabbitmqManagementPort = getenv('RABBITMQ_MANAGEMENT_PORT') ?: '15672';
    
    // Try to connect to RabbitMQ AMQP port
    $context = stream_context_create([
        'socket' => [
            'connect_timeout' => 2,
            'read_timeout' => 2
        ]
    ]);
    
    $rabbitmqSocket = @stream_socket_client("tcp://$rabbitmqHost:$rabbitmqPort", $errno, $errstr, 2, STREAM_CLIENT_CONNECT, $context);
    
    if ($rabbitmqSocket) {
        $rabbitmqStatus['connected'] = true;
        $rabbitmqStatus['management_url'] = "http://$rabbitmqHost:$rabbitmqManagementPort";
        @fclose($rabbitmqSocket);
    } else {
        $rabbitmqStatus['error'] = $errstr ?: 'Could not connect to RabbitMQ';
    }
} catch (Exception $e) {
    $rabbitmqStatus['error'] = $e->getMessage();
}

// Set page title and basic HTML structure
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Deployment Template - PHP Information</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 8px;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            margin: 10px 0 0 0;
            font-size: 1.2em;
            opacity: 0.9;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .info-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .info-card h3 {
            margin: 0 0 15px 0;
            color: #333;
        }
        .info-item {
            display: flex;
            justify-content: space-between;
            margin: 8px 0;
            padding: 5px 0;
            border-bottom: 1px solid #eee;
        }
        .info-label {
            font-weight: bold;
            color: #555;
        }
        .info-value {
            color: #666;
        }
        .phpinfo {
            background: white;
            border: 1px solid #ddd;
            border-radius: 8px;
            overflow: hidden;
        }
        .phpinfo table {
            width: 100%;
            border-collapse: collapse;
        }
        .phpinfo th, .phpinfo td {
            padding: 8px 12px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        .phpinfo th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        .phpinfo tr:nth-child(even) {
            background-color: #f8f9fa;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🐘 Deployment Template PHP Environment</h1>
            <p>PHP Development Environment with Docker</p>
        </div>

        <div class="info-grid">
            <div class="info-card">
                <h3>🚀 Environment</h3>
                <div class="info-item">
                    <span class="info-label">PHP Version:</span>
                    <span class="info-value"><?php echo phpversion(); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Server Software:</span>
                    <span class="info-value"><?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Nginx + PHP-FPM'; ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Document Root:</span>
                    <span class="info-value"><?php echo $_SERVER['DOCUMENT_ROOT'] ?? '/var/www/html'; ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Current Time:</span>
                    <span class="info-value"><?php echo date('Y-m-d H:i:s T'); ?></span>
                </div>
            </div>

            <div class="info-card">
                <h3>🔧 Configuration</h3>
                <div class="info-item">
                    <span class="info-label">Memory Limit:</span>
                    <span class="info-value"><?php echo ini_get('memory_limit'); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Max Execution Time:</span>
                    <span class="info-value"><?php echo ini_get('max_execution_time'); ?>s</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Upload Max Filesize:</span>
                    <span class="info-value"><?php echo ini_get('upload_max_filesize'); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Post Max Size:</span>
                    <span class="info-value"><?php echo ini_get('post_max_size'); ?></span>
                </div>
            </div>

            <div class="info-card">
                <h3>🔌 Extensions</h3>
                <?php
                $extensions = ['mysqli', 'pdo', 'json', 'curl', 'mbstring', 'xml', 'zip', 'gd', 'opcache', 'xdebug'];
                foreach ($extensions as $ext) {
                    $status = extension_loaded($ext) ? '✅' : '❌';
                    echo "<div class='info-item'><span class='info-label'>$ext:</span><span class='info-value'>$status</span></div>";
                }
                ?>
            </div>

            <div class="info-card">
                <h3>🐛 Debugging</h3>
                <div class="info-item">
                    <span class="info-label">Xdebug:</span>
                    <span class="info-value"><?php echo extension_loaded('xdebug') ? '✅ Loaded' : '❌ Not loaded'; ?></span>
                </div>
                <?php if (extension_loaded('xdebug')): ?>
                <div class="info-item">
                    <span class="info-label">Xdebug Version:</span>
                    <span class="info-value"><?php echo phpversion('xdebug'); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Xdebug Mode:</span>
                    <span class="info-value"><?php echo ini_get('xdebug.mode'); ?></span>
                </div>
                <?php endif; ?>
            </div>

            <div class="info-card">
                <h3>⚡ Redis Connection</h3>
                <div class="info-item">
                    <span class="info-label">Status:</span>
                    <span class="info-value"><?php echo $redisStatus['connected'] ? '✅ Connected' : '❌ Failed'; ?></span>
                </div>
                <?php if ($redisStatus['connected']): ?>
                <?php if ($redisStatus['version']): ?>
                <div class="info-item">
                    <span class="info-label">Version:</span>
                    <span class="info-value"><?php echo htmlspecialchars($redisStatus['version']); ?></span>
                </div>
                <?php endif; ?>
                <div class="info-item">
                    <span class="info-label">Keys:</span>
                    <span class="info-value"><?php echo $redisStatus['info']['keys'] ?? '0'; ?></span>
                </div>
                <?php else: ?>
                <div class="info-item">
                    <span class="info-label">Error:</span>
                    <span class="info-value" style="color: #dc3545;"><?php echo htmlspecialchars($redisStatus['error'] ?? 'Unknown error'); ?></span>
                </div>
                <?php endif; ?>
            </div>

            <div class="info-card">
                <h3>🗄️ MySQL Connection</h3>
                <div class="info-item">
                    <span class="info-label">Status:</span>
                    <span class="info-value"><?php echo $mysqlStatus['connected'] ? '✅ Connected' : '❌ Failed'; ?></span>
                </div>
                <?php if ($mysqlStatus['connected']): ?>
                <div class="info-item">
                    <span class="info-label">Version:</span>
                    <span class="info-value"><?php echo htmlspecialchars($mysqlStatus['version']); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Databases:</span>
                    <span class="info-value"><?php echo count($mysqlStatus['databases']); ?></span>
                </div>
                <?php if (!empty($mysqlStatus['databases'])): ?>
                <div class="info-item" style="flex-direction: column; align-items: flex-start;">
                    <span class="info-label" style="margin-bottom: 5px;">Database List:</span>
                    <span class="info-value" style="font-size: 0.9em;"><?php echo htmlspecialchars(implode(', ', $mysqlStatus['databases'])); ?></span>
                </div>
                <?php endif; ?>
                <?php else: ?>
                <div class="info-item">
                    <span class="info-label">Error:</span>
                    <span class="info-value" style="color: #dc3545;"><?php echo htmlspecialchars($mysqlStatus['error'] ?? 'Unknown error'); ?></span>
                </div>
                <?php endif; ?>
            </div>

            <div class="info-card">
                <h3>🐘 PostgreSQL Connection</h3>
                <div class="info-item">
                    <span class="info-label">Status:</span>
                    <span class="info-value"><?php echo $postgresStatus['connected'] ? '✅ Connected' : '❌ Failed'; ?></span>
                </div>
                <?php if ($postgresStatus['connected']): ?>
                <div class="info-item">
                    <span class="info-label">Version:</span>
                    <span class="info-value"><?php echo htmlspecialchars($postgresStatus['version']); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Databases:</span>
                    <span class="info-value"><?php echo count($postgresStatus['databases']); ?></span>
                </div>
                <?php if (!empty($postgresStatus['databases'])): ?>
                <div class="info-item" style="flex-direction: column; align-items: flex-start;">
                    <span class="info-label" style="margin-bottom: 5px;">Database List:</span>
                    <span class="info-value" style="font-size: 0.9em;"><?php echo htmlspecialchars(implode(', ', $postgresStatus['databases'])); ?></span>
                </div>
                <?php endif; ?>
                <?php else: ?>
                <div class="info-item">
                    <span class="info-label">Error:</span>
                    <span class="info-value" style="color: #dc3545;"><?php echo htmlspecialchars($postgresStatus['error'] ?? 'Unknown error'); ?></span>
                </div>
                <?php if (isset($postgresStatus['connection_string'])): ?>
                <div class="info-item">
                    <span class="info-label">Connection String:</span>
                    <span class="info-value" style="font-size: 0.85em; word-break: break-all;"><?php echo htmlspecialchars($postgresStatus['connection_string']); ?></span>
                </div>
                <?php endif; ?>
                <?php if (isset($postgresStatus['debug_info'])): ?>
                <div class="info-item" style="flex-direction: column; align-items: flex-start;">
                    <span class="info-label" style="margin-bottom: 5px;">Debug Info:</span>
                    <span class="info-value" style="font-size: 0.85em; word-break: break-all;"><?php echo htmlspecialchars(json_encode($postgresStatus['debug_info'], JSON_PRETTY_PRINT)); ?></span>
                </div>
                <?php endif; ?>
                <?php endif; ?>
            </div>

            <div class="info-card">
                <h3>🐰 RabbitMQ Connection</h3>
                <div class="info-item">
                    <span class="info-label">Status:</span>
                    <span class="info-value"><?php echo $rabbitmqStatus['connected'] ? '✅ Connected' : '❌ Failed'; ?></span>
                </div>
                <?php if ($rabbitmqStatus['connected']): ?>
                <?php if ($rabbitmqStatus['management_url']): ?>
                <div class="info-item">
                    <span class="info-label">Management URL:</span>
                    <span class="info-value"><a href="<?php echo htmlspecialchars($rabbitmqStatus['management_url']); ?>" target="_blank"><?php echo htmlspecialchars($rabbitmqStatus['management_url']); ?></a></span>
                </div>
                <?php endif; ?>
                <?php else: ?>
                <div class="info-item">
                    <span class="info-label">Error:</span>
                    <span class="info-value" style="color: #dc3545;"><?php echo htmlspecialchars($rabbitmqStatus['error'] ?? 'Unknown error'); ?></span>
                </div>
                <?php endif; ?>
            </div>
        </div>

        <div class="phpinfo">
            <h2 style="padding: 20px; margin: 0; background: #f8f9fa; border-bottom: 1px solid #ddd;">📋 Complete PHP Configuration</h2>
            <?php phpinfo(); ?>
        </div>
    </div>
</body>
</html>