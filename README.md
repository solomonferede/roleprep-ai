# RolePrepAI

**AI-powered interview preparation platform using Django and Google Gemini API**

**Live:** [https://roleprepai.solomonferede.com.et](https://roleprepai.solomonferede.com.et)  
**Repository:** [github.com/solomonferede/roleprep-ai](https://github.com/solomonferede/roleprep-ai)

---

## Features

- 🤖 **AI-Powered Questions** - Generates role-specific interview questions using Google Gemini API
- 🔄 **Key Rotation** - Automatically cycles through multiple API keys when rate limits are hit
- 🚀 **Production Ready** - Fully containerized with Docker and Docker Compose
- 🔒 **Secure** - SSL/TLS via Let's Encrypt, security headers, CSRF protection
- ⚡ **Fast** - WhiteNoise static file serving, Gunicorn workers, Nginx caching
- 📝 **Simple** - Stateless application, no database needed
- 🛠️ **Easy Deployment** - Automated setup and deployment scripts

## Tech Stack

- **Backend:** Django 5.2 with Jinja2 templating
- **AI Integration:** Google Generative AI (Gemini)
- **Server:** Gunicorn + Nginx reverse proxy
- **Containerization:** Docker & Docker Compose
- **Environment:** Ubuntu 24 VPS
- **SSL:** Let's Encrypt / Certbot

## Quick Start

### 1. Initial VPS Setup (First Time Only)

```bash
# Clone repository
git clone https://github.com/solomonferede/roleprep-ai.git
cd roleprep-ai

# Run initial setup (installs Docker, Nginx, Certbot, etc.)
sudo ./setup.sh
```

The setup script will:
- ✅ Install Docker and Docker Compose
- ✅ Install and configure Nginx
- ✅ Install Certbot for SSL certificates
- ✅ Create required directories
- ✅ Copy and validate Nginx configuration

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your actual values
nano .env
```

**Required environment variables:**
```env
SECRET_KEY=your-django-secret-key-here
DEBUG=False
ALLOWED_HOSTS=roleprepai.solomonferede.com.et,localhost,127.0.0.1
GEMINI_API_KEYS=key1,key2,key3  # Comma-separated for rotation
```

### 3. Set Up SSL Certificate

```bash
# Run Certbot (only once)
sudo certbot --nginx -d roleprepai.solomonferede.com.et

# Email: ezezsolomonferede@gmail.com
# Follow the prompts
```

### 4. Deploy Application

```bash
# Make deploy script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

This will:
- ✅ Pull latest code from GitHub
- ✅ Build Docker image
- ✅ Start containers
- ✅ Collect static files
- ✅ Verify health status
- ✅ Clean up old images

## Local Development Setup

### Prerequisites
- Python 3.10+
- Docker & Docker Compose (optional, for local Docker testing)

### Development Environment

```bash
# Clone and navigate to project
git clone https://github.com/solomonferede/roleprep-ai.git
cd roleprep-ai

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create .env for local development
cp .env.example .env
nano .env  # Add your Gemini API key

# Run migrations (if needed)
python manage.py migrate

# Collect static files
python manage.py collectstatic --noinput

# Start development server
python manage.py runserver
```

Visit: http://localhost:8000

## Docker Deployment Guide

### Building Locally

```bash
# Build Docker image
docker compose build

# Start containers
docker compose up -d

# View logs
docker compose logs -f web

# Stop containers
docker compose down
```

### Understanding the Docker Setup

**Dockerfile** - Multi-stage build:
- Stage 1: Builds Python dependencies
- Stage 2: Lightweight runtime image
- Non-root user for security
- Health check included

**docker-compose.yml**:
- Single web service running Gunicorn
- Port 8000 exposed to localhost only
- Nginx handles public traffic (reverse proxy)
- Volume mounts for static files and logs
- Resource limits applied
- Automatic restart policy

**Key volumes:**
- `staticfiles/` - Mounted read-only for Nginx
- `logs/` - Application logs

## Production Deployment Details

### Architecture

```
┌─────────────────────────────────────┐
│   Internet / Client Browser         │
└──────────────┬──────────────────────┘
               │ HTTPS
┌──────────────▼──────────────────────┐
│   Nginx (Reverse Proxy)             │
│   - Handles SSL/TLS                 │
│   - Serves static files             │
│   - Routes to Django app            │
│   - Security headers                │
└──────────────┬──────────────────────┘
               │ HTTP (localhost:8000)
┌──────────────▼──────────────────────┐
│   Django + Gunicorn Container       │
│   - 4 worker processes              │
│   - WhiteNoise static files         │
│   - Application logic               │
└─────────────────────────────────────┘
```

### Nginx Configuration

Nginx handles:
- ✅ SSL/TLS termination
- ✅ HTTP to HTTPS redirect
- ✅ Static file serving (better performance)
- ✅ Security headers
- ✅ Gzip compression
- ✅ Reverse proxy to Django

**File:** `nginx/roleprepai.conf`

### Security Features

1. **SSL/TLS**
   - Let's Encrypt certificates
   - HSTS headers
   - TLS 1.2+ only

2. **Django Security**
   - `DEBUG=False` in production
   - CSRF protection enabled
   - Secure cookie flags
   - Security middleware

3. **Nginx Security**
   - X-Frame-Options
   - X-Content-Type-Options
   - X-XSS-Protection
   - Referrer-Policy
   - Remove sensitive headers

4. **Container Security**
   - Non-root user execution
   - Minimal base image
   - Limited resource allocation

## Updating the Application

### Pulling Latest Changes

```bash
./deploy.sh
```

This script automatically:
1. Pulls latest code
2. Stops old containers
3. Rebuilds images
4. Starts new containers
5. Collects static files
6. Verifies health

### Manual Updates

```bash
# Stop containers
docker compose down

# Pull code
git pull origin main

# Rebuild and start
docker compose up -d --build

# Collect static files
docker compose exec web python manage.py collectstatic --noinput
```

## Viewing Logs

### Docker Logs

```bash
# Real-time logs
docker compose logs -f web

# Last 50 lines
docker compose logs --tail=50 web

# Check specific service
docker compose logs web

# View Nginx logs on host
sudo tail -f /var/log/nginx/roleprepai.access.log
sudo tail -f /var/log/nginx/roleprepai.error.log
```

### Application Logs

Logs are stored in:
- **Container logs:** Via `docker compose logs`
- **Nginx access:** `/var/log/nginx/roleprepai.access.log`
- **Nginx errors:** `/var/log/nginx/roleprepai.error.log`

## Restarting Services

### Restart Django App

```bash
# Restart container
docker compose restart web

# Force restart with rebuild
docker compose up -d --build web
```

### Reload Nginx (Without Downtime)

```bash
# Reload Nginx on host
sudo systemctl reload nginx

# Verify
sudo systemctl status nginx
```

### Stop All Services

```bash
docker compose down
```

### Start Services

```bash
docker compose up -d
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs web

# Verify Docker image
docker images | grep roleprepai

# Check running containers
docker ps

# Inspect container
docker inspect roleprepai-web
```

### Application Not Responding

```bash
# Check health endpoint
curl http://127.0.0.1:8000/health/

# Check Nginx proxy
curl -I https://roleprepai.solomonferede.com.et

# Verify DNS resolution
nslookup roleprepai.solomonferede.com.et
```

### Out of Memory

```bash
# Check resource usage
docker stats

# Limit in docker-compose.yml and redeploy
./deploy.sh
```

### Static Files Not Loading

```bash
# Regenerate static files
docker compose exec web python manage.py collectstatic --noinput

# Verify permissions
ls -la staticfiles/

# Clear browser cache and reload
```

### SSL Certificate Issues

```bash
# Check certificate expiration
sudo certbot certificates

# Renew manually
sudo certbot renew

# Certbot auto-renewal via cron
sudo certbot renew --dry-run
```

## Environment Variables

### Required

| Variable | Example | Purpose |
|----------|---------|---------|
| `SECRET_KEY` | `django-insecure-...` | Django secret key |
| `DEBUG` | `False` | Debug mode (must be False in production) |
| `ALLOWED_HOSTS` | `roleprepai.solomonferede.com.et` | Allowed domains |
| `GEMINI_API_KEYS` | `key1,key2,key3` | Gemini API keys (comma-separated) |

### Optional

| Variable | Default | Purpose |
|----------|---------|---------|
| `GEMINI_API_KEY` | (empty) | Single API key (legacy) |

## Docker Commands Cheat Sheet

```bash
# View running containers
docker compose ps

# View logs
docker compose logs -f

# Execute command in container
docker compose exec web <command>

# Rebuild images
docker compose build --no-cache

# Start services
docker compose up -d

# Stop services
docker compose down

# View resource usage
docker stats

# Clean up unused resources
docker system prune -a

# Check image details
docker image inspect roleprepai-web
```

## Nginx Commands

```bash
# Test configuration
sudo nginx -t

# Reload Nginx (no downtime)
sudo systemctl reload nginx

# Restart Nginx (brief downtime)
sudo systemctl restart nginx

# View status
sudo systemctl status nginx

# View access logs
sudo tail -f /var/log/nginx/roleprepai.access.log

# View error logs
sudo tail -f /var/log/nginx/roleprepai.error.log
```

## Certbot Commands

```bash
# Show all certificates
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Dry run renewal
sudo certbot renew --dry-run

# Interactive certificate setup
sudo certbot --nginx -d roleprepai.solomonferede.com.et
```

## Security Notes

1. **Never commit .env** - Contains sensitive API keys
2. **Keep SECRET_KEY secret** - Don't share or expose
3. **Use strong passwords** - If admin access is needed
4. **Monitor API usage** - Check Gemini API quotas
5. **SSL/TLS always** - Never use HTTP in production
6. **Update regularly** - Keep dependencies updated
7. **Backup configuration** - Keep .env backups safe
8. **Review logs regularly** - Check for suspicious activity

## Scaling Considerations

Currently optimized for:
- Single VPS with 2+ CPU cores
- 1-2GB RAM minimum
- ~1000 requests/day

For higher loads:
- Increase Gunicorn workers in Dockerfile
- Increase resource limits in docker-compose.yml
- Use CDN for static files
- Add caching layer
- Monitor with observability tools

## File Structure

```
roleprep-ai/
├── config/                 # Django settings
│   ├── settings.py        # Main configuration
│   ├── urls.py            # URL routing
│   ├── wsgi.py            # WSGI app
│   └── jinja2.py          # Jinja2 config
├── interviews/            # Main app
│   ├── views.py           # Request handlers
│   ├── urls.py            # App URLs
│   └── models.py          # Database models
├── templates/             # HTML templates
├── static/                # CSS, JS, images
├── nginx/
│   └── roleprepai.conf    # Nginx config
├── Dockerfile             # Container definition
├── docker-compose.yml     # Container orchestration
├── requirements.txt       # Python dependencies
├── .env.example           # Environment template
├── .dockerignore          # Docker build excludes
├── .gitignore             # Git excludes
├── deploy.sh              # Deployment script
├── setup.sh               # Initial setup script
├── manage.py              # Django management
└── README.md              # This file
```

## Screenshots

[Add your application screenshots here]

## Support & Contributing

For issues, feature requests, or contributions, visit the GitHub repository:
https://github.com/solomonferede/roleprep-ai

## License

[Add your license information here]

## Author

Solomon Ferede  
📧 ezezsolomonferede@gmail.com  
🌐 https://solomonferede.com.et

---

**Last Updated:** May 22, 2026

Made with ❤️ for interview preparation
