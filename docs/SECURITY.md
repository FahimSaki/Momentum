# Security Guide

Security features, best practices, and recommendations for Momentum.

## 🛡️ Security Overview

Momentum implements security at multiple layers to protect user data and system integrity:

- **Authentication**: JWT-based with secure token storage
- **Authorization**: Role-based access control for teams
- **Data Protection**: Input validation, sanitization, and secure transmission
- **Infrastructure**: CORS protection, secure headers, and environment isolation

## 🔐 Authentication & Authorization

### JWT Token Security

**Token Generation**:

```javascript
// backend/controllers/authController.js
const token = jwt.sign(
  { userId: user._id },
  process.env.JWT_SECRET,
  { expiresIn: '7d' } // Configurable expiration
);
```

**Security Features**:

- **HS256 Algorithm**: Industry-standard HMAC with SHA-256
- **7-Day Expiration**: Automatic token expiry to limit exposure
- **Secure Secret**: 32+ character random secret key required
- **No Sensitive Data**: Tokens contain only user ID, no passwords or personal info

**Best Practices**:

```bash
# Generate secure JWT secret (32+ characters)
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Environment variable (never in code)
JWT_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
```

### Token Storage

**Mobile (Secure)**:

```dart
// Using FlutterSecureStorage for sensitive data
const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

// Store JWT securely
await _secureStorage.write(key: 'jwt_token', value: token);

// Read JWT securely
final token = await _secureStorage.read(key: 'jwt_token');
```

**Web (Considerations)**:

```dart
// Web uses SharedPreferences (less secure than mobile)
// Consider implementing httpOnly cookies for production web apps
final prefs = await SharedPreferences.getInstance();
await prefs.setString('jwt_token', token);
```

**Security Considerations**:

- ✅ Mobile: FlutterSecureStorage uses keychain/keystore
- ⚠️ Web: SharedPreferences stored in browser (consider httpOnly cookies)
- ✅ Never log tokens in production
- ✅ Clear tokens on logout

### Password Security

**Hashing**:

```javascript
// Strong bcrypt hashing with 12 rounds
const hashedPassword = await bcrypt.hash(password, 12);

// Verification
const isMatch = await bcrypt.compare(password, user.password);
```

**Password Requirements**:

- Minimum 6 characters (configurable)
- No maximum length limit
- Support for special characters
- Client-side validation with server-side enforcement

**Best Practices**:

```javascript
// backend/controllers/authController.js
if (!password || password.length < 6) {
  return res.status(400).json({
    message: 'Password must be at least 6 characters long'
  });
}

// Never log passwords
console.log('Login attempt for:', email); // ✅ Safe
console.log('Password:', password);        // ❌ Never do this
```

### Session Management

**Token Validation**:

```javascript
// middleware/middle_auth.js
export const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId);

    if (!user) {
      return res.status(401).json({ message: 'Invalid token - user not found' });
    }

    req.user = user;
    req.userId = user._id.toString();
    next();
  } catch (error) {
    return res.status(403).json({ message: 'Invalid or expired token' });
  }
};
```

**Automatic Token Validation**:

```dart
// services/auth_service.dart - Check token validity
static Future<bool> validateToken() async {
  try {
    final authData = await getStoredAuthData();
    if (authData == null) return false;

    final response = await http.get(
      Uri.parse('$apiBaseUrl/auth/validate'),
      headers: {'Authorization': 'Bearer ${authData['token']}'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await logout(); // Clear invalid token
      return false;
    }

    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}
```

## 🔒 Data Protection

### Input Validation

**Backend Validation**:

```javascript
// controllers/authController.js
export const register = async (req, res) => {
  const { email, password, name } = req.body;

  // Required field validation
  if (!email || !email.trim()) {
    return res.status(400).json({ message: 'Email is required' });
  }

  if (!password || password.length < 6) {
    return res.status(400).json({
      message: 'Password must be at least 6 characters long'
    });
  }

  if (!name || !name.trim()) {
    return res.status(400).json({ message: 'Name is required' });
  }

  // Email format validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ message: 'Invalid email format' });
  }

  // Sanitize inputs
  const sanitizedEmail = email.toLowerCase().trim();
  const sanitizedName = name.trim();

  // Continue with user creation...
};
```

**Frontend Validation**:

```dart
// pages/register_page.dart
void register() async {
  final email = emailController.text.trim();
  final password = passwordController.text.trim();
  final name = nameController.text.trim();

  // Client-side validation
  if (email.isEmpty || password.isEmpty || name.isEmpty) {
    setState(() {
      error = "Please fill in all fields.";
    });
    return;
  }

  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegex.hasMatch(email)) {
    setState(() {
      error = "Please enter a valid email address.";
    });
    return;
  }

  if (password.length < 6) {
    setState(() {
      error = "Password must be at least 6 characters long.";
    });
    return;
  }

  // Proceed with registration...
}
```

### Data Sanitization

**MongoDB Injection Prevention**:

```javascript
// Mongoose automatically escapes queries, but additional validation:
const createTask = async (req, res) => {
  const { name, description } = req.body;

  // Validate and sanitize
  if (!name || typeof name !== 'string') {
    return res.status(400).json({ message: 'Invalid task name' });
  }

  const sanitizedName = name.trim().substring(0, 200); // Limit length
  const sanitizedDescription = description ? 
    description.trim().substring(0, 1000) : undefined;

  // Create task with sanitized data
  const task = new Task({
    name: sanitizedName,
    description: sanitizedDescription,
    // ...
  });
};
```

### Sensitive Data Handling

**Environment Variables**:

```bash
# backend/.env - Never commit to version control
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/momentum
JWT_SECRET=your_super_secure_32_character_secret_key
FIREBASE_SERVICE_ACCOUNT_PATH=/etc/secrets/firebase-key.json

# Use different secrets for different environments
# Development
JWT_SECRET=dev_secret_key_32_chars_minimum

# Production  
JWT_SECRET=prod_ultra_secure_64_character_secret_key_here
```

**Logging Security**:

```javascript
// ✅ Safe logging
console.log('User login attempt:', { email, timestamp: new Date() });

// ❌ Never log sensitive data
console.log('User data:', { email, password, jwt }); // Dangerous!

// ✅ Production logging
if (process.env.NODE_ENV === 'development') {
  console.log('Debug info:', debugData);
}
```

## 🌐 Network Security

### CORS Configuration

**Development vs Production**:

```javascript
// backend/index.js
app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true); // Allow mobile apps

    const allowedOrigins = [
      'https://momentum-beryl-nine.vercel.app', // Production
      'http://localhost:3000', // Development
      'http://127.0.0.1:3000', // Alternative localhost
    ];

    // Allow Vercel preview URLs
    if (allowedOrigins.includes(origin) || origin.endsWith('.vercel.app')) {
      callback(null, true);
    } else {
      console.warn(`CORS origin rejected: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'Accept',
    'Origin',
    'X-Requested-With'
  ],
  credentials: true,
  optionsSuccessStatus: 200
}));
```

### HTTPS/TLS

**Production Requirements**:

```bash
# Always use HTTPS in production
https://your-domain.com/api/tasks

# Never use HTTP for sensitive data
http://your-domain.com/api/login  # ❌ Insecure

# SSL Certificate with Let's Encrypt (free)
sudo certbot --nginx -d your-domain.com
```

**API Base URL Security**:

```dart
// constants/api_base_url.dart
const String apiBaseUrl = kIsWeb
    ? 'https://mome***um.onrender.com'  // ✅ HTTPS for web
    : (kReleaseMode
          ? 'https://mome***um.onrender.com'  // ✅ HTTPS for production
          : 'http://10.0.2.2:10000'); // ✅ HTTP only for development
```

## 🔧 Infrastructure Security

### Database Security

**MongoDB Security**:

```bash
# Enable authentication
mongod --auth

# Create admin user
mongo
use admin
db.createUser({
  user: "admin",
  pwd: "secure_password_here",
  roles: ["userAdminAnyDatabase", "dbAdminAnyDatabase", "readWriteAnyDatabase"]
})

# Application user with limited privileges
use momentum
db.createUser({
  user: "momentum_app",
  pwd: "app_specific_password",
  roles: ["readWrite"]
})
```

**MongoDB Atlas Security**:

- ✅ Enable network access restrictions (IP whitelist)
- ✅ Use strong database user passwords
- ✅ Enable connection encryption (TLS)
- ✅ Regular security updates (managed automatically)
- ✅ Database auditing (available in higher tiers)

**Connection String Security**:

```bash
# ✅ Secure connection string
MONGODB_URI=mongodb+srv://app_user:secure_pass@cluster.mongodb.net/momentum?retryWrites=true&w=majority&ssl=true

# ❌ Insecure (no TLS, weak password)
MONGODB_URI=mongodb://admin:123456@cluster.mongodb.net/momentum
```

### Server Security Headers

**Express Security Headers**:

```javascript
// backend/index.js - Add security headers
const helmet = require('helmet');

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Custom security headers
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  next();
});
```

### Environment Separation

**Development**:

```bash
# backend/.env.development
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/momentum_dev
JWT_SECRET=dev_secret_key_32_characters_minimum
DEBUG=true
LOG_LEVEL=debug
```

**Production**:

```bash
# backend/.env.production
NODE_ENV=production
MONGODB_URI=mongodb+srv://user:secure_pass@cluster.mongodb.net/momentum_prod
JWT_SECRET=production_ultra_secure_64_character_secret_key
DEBUG=false
LOG_LEVEL=warn
```

## 📱 Mobile Security

### Android Security

**Network Security Config**:

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">momentum-to2e.onrender.com</domain>
    </domain-config>
    
    <!-- Only allow cleartext for development -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">localhost</domain>
    </domain-config>
</network-security-config>
```

**App Permissions**:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<!-- Only request permissions you actually need -->
```

### iOS Security

**App Transport Security**:

```xml
<!-- ios/Runner/Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>momentum-to2e.onrender.com</key>
        <dict>
            <key>NSRequiresForwardSecrecy</key>
            <false/>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <false/>
        </dict>
        <!-- Allow localhost only for development -->
        <key>localhost</key>
        <dict>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSTemporaryExceptionMinimumTLSVersion</key>
            <string>1.0</string>
        </dict>
    </dict>
</dict>
```

## 🔍 Security Monitoring & Logging

### Audit Logging

**Authentication Events**:

```javascript
// backend/controllers/authController.js
export const login = async (req, res) => {
  const { email } = req.body;
  
  try {
    // Log successful login
    console.log(`✅ Login successful: ${email} at ${new Date().toISOString()}`);
    
    // Update last login timestamp
    await User.findByIdAndUpdate(user._id, {
      lastLoginAt: new Date()
    });
    
  } catch (err) {
    // Log failed login attempts
    console.log(`❌ Login failed: ${email} at ${new Date().toISOString()}`);
    console.error('Login error:', err.message);
  }
};
```

**API Access Logging**:

```javascript
// backend/index.js - Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logEntry = {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      timestamp: new Date().toISOString()
    };
    
    // Log suspicious activities
    if (res.statusCode === 401 || res.statusCode === 403) {
      console.warn('🚨 Unauthorized access attempt:', logEntry);
    }
    
    // Log errors
    if (res.statusCode >= 500) {
      console.error('💥 Server error:', logEntry);
    }
  });
  
  next();
});
```

### Error Handling Security

**Safe Error Messages**:

```javascript
// ✅ Safe error responses (production)
export const safeErrorResponse = (res, error, statusCode = 500) => {
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  return res.status(statusCode).json({
    message: error.message || 'Internal server error',
    // Only include stack traces in development
    ...(isDevelopment && {
      stack: error.stack,
      details: error
    })
  });
};

// Usage
try {
  // Database operation
} catch (error) {
  console.error('Database error:', error); // Log full error
  return safeErrorResponse(res, new Error('Database operation failed'), 500);
}
```

**Client-Side Error Handling**:

```dart
// components/error_handler.dart
class ErrorHandler {
  static String _extractErrorMessage(dynamic error) {
    String message = error.toString();
    
    // Remove sensitive information
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }
    
    // Generic messages for security
    if (message.toLowerCase().contains('database')) {
      return 'A system error occurred. Please try again.';
    }
    
    if (message.toLowerCase().contains('unauthorized')) {
      return 'Your session has expired. Please login again.';
    }
    
    return message;
  }
}
```

## 🚨 Incident Response

### Security Incident Checklist

**Immediate Response**:

1. **Identify the Issue**
   - [ ] Determine scope and impact
   - [ ] Check logs for suspicious activity
   - [ ] Identify affected users/data

2. **Contain the Incident**
   - [ ] Rotate compromised credentials immediately
   - [ ] Block malicious IP addresses
   - [ ] Disable affected user accounts if necessary

3. **Assess Damage**
   - [ ] Check database for unauthorized changes
   - [ ] Review authentication logs
   - [ ] Verify data integrity

4. **Recovery**
   - [ ] Restore from clean backups if needed
   - [ ] Update security measures
   - [ ] Force password resets if needed

**Security Incident Response Script**:

```bash
#!/bin/bash
# security-incident-response.sh

echo "🚨 Security Incident Response"

# 1. Backup current state
mongodump --uri="$MONGODB_URI" --out="/backups/incident_$(date +%Y%m%d_%H%M%S)"

# 2. Check for suspicious users
mongo momentum --eval "
db.users.find({
  createdAt: { \$gte: new Date(Date.now() - 24*60*60*1000) }
}).pretty()
"

# 3. Check recent failed login attempts
grep "Login failed" /var/log/momentum/app.log | tail -20

# 4. Rotate JWT secret (will invalidate all tokens)
NEW_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
echo "New JWT secret generated: $NEW_SECRET"
echo "Update environment variable and restart server"

# 5. Monitor for unusual activity
echo "Monitor /var/log/momentum/app.log for further suspicious activity"
```

### Vulnerability Reporting

**Security Contact**:

- 🔒 **Security Issues**: Email <security@yourdomain.com>
- 🐛 **General Bugs**: [GitHub Issues](../../issues)
- 💬 **Questions**: [GitHub Discussions](../../discussions)

**Responsible Disclosure**:

1. **Report privately** via security email
2. **Include details**: Steps to reproduce, potential impact
3. **Allow time**: 90 days for fix before public disclosure
4. **Recognition**: Security researchers credited in releases

## 🔒 Security Checklist

### Development Security

- [ ] **Environment Variables**: All secrets in `.env` files, never in code
- [ ] **Input Validation**: Both client and server-side validation
- [ ] **Error Handling**: Safe error messages, no sensitive data exposure
- [ ] **Logging**: Audit trails for authentication and critical operations
- [ ] **Dependencies**: Regular updates, vulnerability scanning

### Deployment Security

- [ ] **HTTPS Only**: All production traffic encrypted with TLS
- [ ] **Strong Passwords**: Database, admin accounts, JWT secrets
- [ ] **Network Security**: CORS configured, firewall rules in place
- [ ] **Access Control**: Principle of least privilege for all accounts
- [ ] **Monitoring**: Log aggregation and alerting configured

### Database Security

- [ ] **Authentication**: Database authentication enabled
- [ ] **Encryption**: Data encrypted at rest and in transit
- [ ] **Backup Security**: Encrypted backups, secure storage
- [ ] **Access Logging**: Database access audit logs enabled
- [ ] **Network**: Database not exposed to public internet

### Mobile App Security

- [ ] **Secure Storage**: Sensitive data in secure storage (keychain/keystore)
- [ ] **Network Security**: Certificate pinning for production APIs
- [ ] **Code Obfuscation**: Release builds obfuscated
- [ ] **Permissions**: Minimal required permissions only
- [ ] **App Store**: Published through official app stores only

## 📚 Security Resources

### Training & Education

**Secure Coding Practices**:

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Flutter Security](https://docs.flutter.dev/deployment/security)
- [Node.js Security](https://nodejs.org/en/docs/guides/security/)
- [MongoDB Security](https://docs.mongodb.com/manual/security/)

**Security Tools**:

- **Dependency Scanning**: `npm audit`, `flutter pub deps`
- **Static Analysis**: ESLint security rules, Dart analyzer
- **Penetration Testing**: OWASP ZAP, Burp Suite
- **Vulnerability Databases**: [CVE](https://cve.mitre.org/), [npm advisory](https://www.npmjs.com/advisories)

### Regular Security Tasks

**Weekly**:

- [ ] Review authentication logs for anomalies
- [ ] Check for failed login attempts patterns
- [ ] Monitor system resource usage

**Monthly**:

- [ ] Update all dependencies
- [ ] Review and rotate API keys
- [ ] Audit user permissions and roles
- [ ] Test backup and recovery procedures

**Quarterly**:

- [ ] Security vulnerability assessment
- [ ] Review and update security policies
- [ ] Penetration testing (if applicable)
- [ ] Security training for team members

**Annually**:

- [ ] Comprehensive security audit
- [ ] Update SSL/TLS certificates
- [ ] Review and update incident response plan
- [ ] Security architecture review

## 🔐 Security Configuration Examples

### Production Environment Variables

```bash
# backend/.env.production
NODE_ENV=production
PORT=3000

# Database (MongoDB Atlas recommended for production)
MONGODB_URI=mongodb+srv://prod_user:ultra_secure_password@cluster.mongodb.net/momentum_prod?retryWrites=true&w=majority

# Authentication
JWT_SECRET=production_64_character_secret_key_never_commit_to_version_control

# Firebase (for notifications)
FIREBASE_SERVICE_ACCOUNT_PATH=/etc/secrets/momentum-firebase-prod.json

# Logging & Monitoring
LOG_LEVEL=warn
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id

# Security
BCRYPT_ROUNDS=12
SESSION_TIMEOUT=604800  # 7 days in seconds
RATE_LIMIT_MAX=100      # Requests per window
RATE_LIMIT_WINDOW=900000 # 15 minutes in ms
```

### Security Headers Configuration

```javascript
// backend/middleware/security.js
import helmet from 'helmet';

export const securityMiddleware = () => {
  return [
    // Helmet for security headers
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: ["'self'", "https://api.yourdomain.com"],
          fontSrc: ["'self'", "https:", "data:"],
          objectSrc: ["'none'"],
          mediaSrc: ["'self'"],
          frameSrc: ["'none'"],
        },
      },
      crossOriginEmbedderPolicy: false, // May interfere with some CDNs
    }),

    // Custom security headers
    (req, res, next) => {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('X-Frame-Options', 'DENY');
      res.setHeader('X-XSS-Protection', '1; mode=block');
      res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
      res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
      next();
    }
  ];
};
```

### Rate Limiting

```javascript
// backend/middleware/rate-limit.js
import rateLimit from 'express-rate-limit';

// General API rate limiting
export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Strict rate limiting for authentication endpoints
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per windowMs
  message: {
    error: 'Too many authentication attempts, please try again later.'
  },
  skipSuccessfulRequests: true, // Don't count successful requests
});

// Usage in routes
app.use('/api/', generalLimiter);
app.use('/auth/login', authLimiter);
app.use('/auth/register', authLimiter);
```

---

## ⚠️ Security Warnings

### Never Do This

```javascript
// ❌ NEVER store secrets in code
const JWT_SECRET = "hardcoded-secret-key";

// ❌ NEVER log sensitive data
console.log('User password:', password);
console.log('JWT token:', token);

// ❌ NEVER trust user input without validation
app.post('/tasks', (req, res) => {
  const task = new Task(req.body); // Dangerous!
});

// ❌ NEVER use weak secrets
JWT_SECRET=123456
MONGODB_URI=mongodb://admin:password@localhost/momentum

// ❌ NEVER disable security features in production
app.use(cors({ origin: '*' })); // Dangerous!
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'; // Very dangerous!
```

### Always Do This

```javascript
// ✅ Use environment variables for secrets
const JWT_SECRET = process.env.JWT_SECRET;

// ✅ Validate and sanitize input
const createTask = async (req, res) => {
  const { name, description } = req.body;
  
  if (!name || typeof name !== 'string' || name.length > 200) {
    return res.status(400).json({ message: 'Invalid task name' });
  }
  
  const sanitizedName = name.trim();
  // Continue with sanitized data...
};

// ✅ Use strong, random secrets
JWT_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6

// ✅ Configure CORS properly
app.use(cors({
  origin: ['https://yourdomain.com'],
  credentials: true
}));
```

---

**Security is a shared responsibility**. While this guide covers the technical aspects, remember that security also depends on:

- 👥 **Team practices**: Regular security training and awareness
- 🔄 **Process**: Code reviews, security testing, incident response
- 🌐 **Infrastructure**: Secure hosting, network configuration, monitoring
- 📱 **Users**: Strong passwords, device security, awareness of phishing

Stay vigilant, keep learning, and always prioritize security in your development process! 🛡️

---

**Related Documentation**:

- 🏗️ [Architecture Guide](ARCHITECTURE.md)
- 🚀 [Deployment Guide](DEPLOYMENT.md)
- 🐛 [Troubleshooting Guide](TROUBLESHOOTING.md)
- 📡 [API Documentation](API.md)
