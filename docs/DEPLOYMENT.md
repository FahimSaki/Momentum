# Deployment Guide

Complete guide for deploying Momentum in production environments.

## 🎯 Deployment Options

| Platform | Backend | Database | Frontend | Complexity | Cost |
|----------|---------|----------|----------|------------|------|
| **Self-Hosted VPS** | Node.js + PM2 | MongoDB | Static Files | Medium | $5-20/month |
| **Cloud Platform** | Render/Railway | MongoDB Atlas | Vercel/Netlify | Low | $0-25/month |
| **Docker** | Docker Compose | MongoDB Container | Nginx | Medium | Variable |
| **Enterprise** | Kubernetes | Managed DB | CDN | High | $50+/month |

## 🚀 Quick Deployment (Render + MongoDB Atlas)

### 1. Database Setup (MongoDB Atlas)

**Create MongoDB Atlas Account**:

1. Go to [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)
2. Create free account and cluster (M0 tier)
3. Create database user: `Database Access` → `Add New User`
4. Whitelist IPs: `Network Access` → `Add IP Address` → `Allow Access from Anywhere`
5. Get connection string: `Connect` → `Connect Your Application`

### 2. Backend Deployment (Render)

**Deploy to Render**:

1. Fork/clone your repository to GitHub
2. Go to [render.com](https://render.com) and connect GitHub
3. Create new `Web Service`
4. Configure:
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Node Version**: 16+

**Environment Variables** (Render Dashboard):

```bash
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/momentum
JWT_SECRET=your_32_character_secret_key_here
NODE_ENV=production
PORT=10000
```

### 3. Frontend Deployment (Vercel)

**Deploy Flutter Web**:

```bash
# Build for web
flutter build web --release

# Deploy to Vercel
npm i -g vercel
cd build/web
vercel --prod
```

**Update API Base URL**:

```dart
// lib/constants/api_base_url.dart - Update for your deployment
const String apiBaseUrl = kIsWeb
    ? 'https://your-app.onrender.com'  // Your Render URL
    : (kReleaseMode
          ? 'https://your-app.onrender.com' // Production
          : 'http://10.0.2.2:10000'); // Development

// Or use the dynamic function for environment-based URLs
String getApiBaseUrl() {
  if (kIsWeb) {
    return 'https://your-app.onrender.com';
  } else if (kDebugMode) {
    return Platform.isAndroid 
        ? 'http://10.0.2.2:10000' 
        : 'http://127.0.0.1:10000';
  }
  return 'https://your-app.onrender.com';
}
```

---

## 🖥️ Self-Hosted VPS Deployment

### Prerequisites

- VPS with Ubuntu 20.04+ (2GB RAM, 1 CPU minimum)
- Domain name (optional but recommended)
- SSH access to server

### 1. Server Setup

**Update System**:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install curl wget git nginx certbot python3-certbot-nginx -y
```

**Install Node.js**:

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y
node --version  # Should be 18+
```

**Install MongoDB**:

```bash
# Import GPG key
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

# Add repository
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Install MongoDB
sudo apt update
sudo apt install mongodb-org -y

# Start and enable MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod
```

**Install PM2 (Process Manager)**:

```bash
sudo npm install -g pm2
```

### 2. Application Deployment

**Clone and Setup Backend**:

```bash
# Clone repository
git clone <your-repo-url>
cd momentum/backend

# Install dependencies
npm install --production

# Create production environment file
sudo nano .env
```

**Production .env**:

```bash
MONGODB_URI=mongodb://localhost:27017/momentum_prod
JWT_SECRET=your_super_secure_32_character_secret_key
NODE_ENV=production
PORT=3000
CLEANUP_ENABLED=true
```

**Start with PM2**:

```bash
# Start application
pm2 start index.js --name "momentum-backend" --env production

# Save PM2 configuration
pm2 save

# Setup PM2 startup script
pm2 startup
# Follow the instructions displayed
```

### 3. Nginx Configuration

**Create Nginx Config**:

```bash
sudo nano /etc/nginx/sites-available/momentum
```

**Nginx Configuration**:

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    
    # API proxy
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Flutter web app
    location / {
        root /var/www/momentum;
        try_files $uri $uri/ /index.html;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        root /var/www/momentum;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Enable Site**:

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/momentum /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### 4. SSL Certificate (Let's Encrypt)

```bash
# Get SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal (already set up, but verify)
sudo crontab -l | grep certbot
```

### 5. Frontend Deployment

**Build Flutter Web**:

```bash
# On your development machine
flutter build web --release --web-renderer html

# Upload to server
scp -r build/web/* user@your-server:/var/www/momentum/
```

**Or build on server**:

```bash
# Install Flutter on server
git clone https://github.com/flutter/flutter.git /opt/flutter
export PATH="$PATH:/opt/flutter/bin"
echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc

# Build app
cd momentum
flutter build web --release
sudo cp -r build/web/* /var/www/momentum/
```

---

## 🐳 Docker Deployment

### Docker Compose Setup

**Create `docker-compose.yml`**:

```yaml
version: '3.8'

services:
  # MongoDB Database
  mongodb:
    image: mongo:6.0
    container_name: momentum-db
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: secure_password_here
      MONGO_INITDB_DATABASE: momentum
    volumes:
      - mongodb_data:/data/db
      - ./init-mongo.js:/docker-entrypoint-initdb.d/init-mongo.js:ro
    ports:
      - "27017:27017"
    networks:
      - momentum-network

  # Node.js Backend
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: momentum-backend
    restart: unless-stopped
    environment:
      NODE_ENV: production
      MONGODB_URI: mongodb://admin:secure_password_here@mongodb:27017/momentum?authSource=admin
      JWT_SECRET: your_32_character_secret_key_here
      PORT: 3000
    ports:
      - "3000:3000"
    depends_on:
      - mongodb
    networks:
      - momentum-network

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: momentum-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./frontend/build/web:/usr/share/nginx/html:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - backend
    networks:
      - momentum-network

networks:
  momentum-network:
    driver: bridge

volumes:
  mongodb_data:
```

**Create `backend/Dockerfile`**:

```dockerfile
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Bundle app source
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S momentum -u 1001
USER momentum

# Expose port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
```

**Create `nginx.conf`**:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend:3000;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        # API routes
        location /api/ {
            proxy_pass http://backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Frontend
        location / {
            root /usr/share/nginx/html;
            try_files $uri $uri/ /index.html;
            include /etc/nginx/mime.types;
        }
    }
}
```

**Deploy with Docker**:

```bash
# Build and start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## ☸️ Kubernetes Deployment

### Basic K8s Configuration

**Create `k8s/namespace.yaml`**:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: momentum
```

**Create `k8s/mongodb.yaml`**:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
  namespace: momentum
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  namespace: momentum
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:6.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "admin"
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: password
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
      volumes:
      - name: mongodb-storage
        persistentVolumeClaim:
          claimName: mongodb-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb-service
  namespace: momentum
spec:
  selector:
    app: mongodb
  ports:
  - port: 27017
    targetPort: 27017
```

**Create `k8s/backend.yaml`**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: momentum-backend
  namespace: momentum
spec:
  replicas: 2
  selector:
    matchLabels:
      app: momentum-backend
  template:
    metadata:
      labels:
        app: momentum-backend
    spec:
      containers:
      - name: backend
        image: your-registry/momentum-backend:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: MONGODB_URI
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: mongodb-uri
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: momentum
spec:
  selector:
    app: momentum-backend
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
```

**Deploy to Kubernetes**:

```bash
# Create secrets
kubectl create secret generic mongodb-secret \
  --from-literal=password=your_secure_password \
  --namespace=momentum

kubectl create secret generic app-secrets \
  --from-literal=mongodb-uri='mongodb://admin:your_secure_password@mongodb-service:27017/momentum?authSource=admin' \
  --from-literal=jwt-secret='your_32_character_secret_key' \
  --namespace=momentum

# Apply configurations
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/mongodb.yaml
kubectl apply -f k8s/backend.yaml

# Check deployment
kubectl get pods -n momentum
```

---

## 📱 Mobile App Distribution

### Android APK Release

**Build Release APK**:

```bash
# Build release APK
flutter build apk --release

# Build App Bundle (for Google Play)
flutter build appbundle --release
```

**Sign APK** (for distribution):

```bash
# Generate keystore (first time only)
keytool -genkey -v -keystore ~/momentum-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias momentum

# Configure signing in android/app/build.gradle
android {
    signingConfigs {
        release {
            keyAlias 'momentum'
            keyPassword 'your_key_password'
            storeFile file('/path/to/momentum-key.jks')
            storePassword 'your_store_password'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### iOS Release (macOS only)

**Build iOS Release**:

```bash
# Build for iOS
flutter build ios --release

# Or build IPA for distribution
flutter build ipa --release
```

**App Store Distribution**:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device" as build target
3. Product → Archive
4. Upload to App Store Connect

---

## 🔧 Production Configuration

### Environment Variables

**Backend Production `.env`**:

```bash
# Database
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/momentum_prod

# Security
JWT_SECRET=your_ultra_secure_32_character_minimum_secret_key
NODE_ENV=production

# Server
PORT=3000

# Features
CLEANUP_ENABLED=true

# External Services
FIREBASE_SERVICE_ACCOUNT_PATH=/etc/secrets/firebase-key.json

# Monitoring (optional)
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project
LOG_LEVEL=info
```

### Security Checklist

- [ ] **JWT Secret**: Use 32+ character random string
- [ ] **Database**: Enable authentication and use strong passwords
- [ ] **HTTPS**: Use SSL certificates (Let's Encrypt or purchased)
- [ ] **CORS**: Configure proper origin whitelist
- [ ] **Headers**: Set security headers (CSP, HSTS, etc.)
- [ ] **Input Validation**: Validate all user inputs
- [ ] **Rate Limiting**: Implement API rate limiting
- [ ] **Secrets**: Store secrets in environment variables, never in code
- [ ] **Updates**: Keep dependencies updated

### Performance Optimization

**Backend**:

```javascript
// Add to index.js for production
const compression = require('compression');
const helmet = require('helmet');

app.use(helmet()); // Security headers
app.use(compression()); // Gzip compression

// Connection pooling
mongoose.connect(process.env.MONGODB_URI, {
  maxPoolSize: 10,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
});
```

**Database Indexing**:

```javascript
// Create indexes for production
db.users.createIndex({ email: 1 }, { unique: true });
db.tasks.createIndex({ assignedTo: 1, isArchived: 1 });
db.tasks.createIndex({ team: 1, createdAt: -1 });
db.notifications.createIndex({ recipient: 1, isRead: 1 });
```

**Monitoring**:

- Use tools like **PM2** for process monitoring
- Set up **log rotation** to prevent disk space issues
- Monitor **memory usage** and **CPU utilization**
- Set up **database backups** (daily recommended)

### Backup Strategy

**Database Backup**:

```bash
# MongoDB backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
mongodump --uri="$MONGODB_URI" --out="/backups/momentum_$DATE"
tar -czf "/backups/momentum_$DATE.tar.gz" "/backups/momentum_$DATE"
rm -rf "/backups/momentum_$DATE"

# Keep only last 7 backups
find /backups -name "momentum_*.tar.gz" -type f -mtime +7 -delete
```

**Automated Backups**:

```bash
# Add to crontab (daily at 2 AM)
crontab -e
0 2 * * * /path/to/backup-script.sh >> /var/log/momentum-backup.log 2>&1
```

---

## 📊 Monitoring & Logging

### Health Checks

**Backend Health Endpoint**:

```javascript
// Already implemented in your backend
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok',
    timestamp: new Date(),
    uptime: process.uptime()
  });
});
```

**Monitoring Setup**:

```bash
# Setup basic monitoring with PM2
pm2 install pm2-server-monit

# Or use external monitoring
curl -f http://localhost:3000/health || echo "Service is down"
```

### Log Management

**Production Logging**:

```javascript
// Add structured logging
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions Example

**Create `.github/workflows/deploy.yml`**:

```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: actions/setup-node@v3
      with:
        node-version: '18'
    - name: Test Backend
      run: |
        cd backend
        npm install
        npm test
    
  deploy-backend:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Deploy to Render
      # Use Render's deployment hook or API
      run: |
        curl -X POST ${{ secrets.RENDER_DEPLOY_HOOK }}
  
  deploy-frontend:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.x'
    - name: Build and Deploy
      run: |
        flutter build web --release
        # Deploy to your hosting provider
```

---

## 🚨 Troubleshooting Production Issues

### Common Problems

**Backend Won't Start**:

```bash
# Check logs
pm2 logs momentum-backend
# or
docker logs momentum-backend

# Common issues:
# - Missing environment variables
# - Database connection failed
# - Port already in use
```

**Database Connection Issues**:

```bash
# Test MongoDB connection
mongo "mongodb://localhost:27017/momentum_prod"

# Check MongoDB logs
sudo tail -f /var/log/mongodb/mongod.log
```

**Frontend Not Loading**:

```bash
# Check Nginx configuration
sudo nginx -t

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Rebuild frontend
flutter clean && flutter build web --release
```

### Performance Issues

**High Memory Usage**:

```bash
# Check memory usage
free -h
pm2 monit

# Restart if needed
pm2 restart momentum-backend
```

**Slow Database Queries**:

```javascript
// Enable MongoDB profiling
db.setProfilingLevel(1, { slowms: 100 });
db.system.profile.find().sort({ts: -1}).limit(5);
```

---

## 📞 Support & Maintenance

### Regular Maintenance Tasks

- **Weekly**: Check server resources and logs
- **Monthly**: Update dependencies and security patches  
- **Quarterly**: Review and optimize database performance
- **Annually**: Update SSL certificates (if not auto-renewing)

### Getting Help

- 📖 **Documentation**: [Main README](../README.md)
- 🐛 **Issues**: [GitHub Issues](../../issues)
- 💬 **Discussions**: [GitHub Discussions](../../discussions)
- 🔧 **Architecture**: [Architecture Guide](ARCHITECTURE.md)

---

**Next Steps**:

- 🔐 [Security Best Practices](SECURITY.md)
- ⚡ [Performance Optimization](PERFORMANCE.md)
- 🐛 [Troubleshooting Guide](TROUBLESHOOTING.md)
