module.exports = {
  apps: [{
    name: 'gamedevmap-api',
    script: 'server/index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    error_file: '/home/www/GameDevMap/logs/error.log',
    out_file: '/home/www/GameDevMap/logs/out.log',
    log_file: '/home/www/GameDevMap/logs/combined.log',
    time: true
  }]
};