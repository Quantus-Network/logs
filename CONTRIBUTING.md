# Contributing to Graylog Docker Setup

Thank you for your interest in contributing to this project! 🎉

## How Can I Help?

- 🐛 Report bugs
- 💡 Propose new features
- 📝 Improve documentation
- 🔧 Submit Pull Requests
- ⭐ Star the project!

## Reporting Bugs

If you found a bug, open an Issue and provide:

1. **Problem description** - what happened?
2. **Steps to reproduce** - how to trigger the problem?
3. **Expected behavior** - what should happen?
4. **Environment**:
   - Docker version: `docker --version`
   - Docker Compose version: `docker-compose --version`
   - Operating system
5. **Logs** - if you have them:
   ```bash
   docker-compose logs > logs.txt
   ```

## Proposing Changes

1. Check if the issue already exists
2. Describe your proposal in detail
3. Explain why it's needed
4. If possible, provide an example implementation

## Pull Requests

### Process

1. **Fork** the repository
2. **Clone** your fork
   ```bash
   git clone https://github.com/YOUR-USERNAME/logs.git
   cd logs
   ```

3. **Create branch** for your change
   ```bash
   git checkout -b feature/my-new-feature
   # or
   git checkout -b fix/bug-fix
   ```

4. **Make changes**
   - Test locally
   - Ensure everything works
   - Update documentation if needed

5. **Commit** with clear description
   ```bash
   git add .
   git commit -m "feat: add new feature X"
   # or
   git commit -m "fix: fix issue with Y"
   ```

6. **Push** to your fork
   ```bash
   git push origin feature/my-new-feature
   ```

7. **Open Pull Request** on GitHub

### Commit Conventions

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - new feature
- `fix:` - bug fix
- `docs:` - documentation changes
- `style:` - formatting, missing semicolons, etc.
- `refactor:` - code refactoring
- `test:` - adding or fixing tests
- `chore:` - build changes, tools, etc.

Examples:
```
feat: add support for custom inputs
fix: fix MongoDB connection issue
docs: update README with new ports
chore: update Graylog version to 5.2
```

### What Should a Good PR Contain?

1. **Clear title and description**
   - What was changed?
   - Why?
   - Does it relate to any issue?

2. **Tests**
   - Ensure the change works
   - Test on clean installation

3. **Documentation**
   - Update README.md if needed
   - Update SETUP_GUIDE.md if needed
   - Add usage examples

4. **CHANGELOG**
   - Add entry to CHANGELOG.md in [Unreleased] section

## Project Structure

```
.
├── docker-compose.yml              # Main configuration
├── docker-compose.prod.yml         # Production configuration
├── docker-compose.override.yml.example  # Override example
├── env.template                    # .env template
├── setup.sh                        # Initialization script
├── Makefile                        # Management commands
├── README.md                       # Main documentation
├── QUICKSTART.md                   # Quick start
├── SETUP_GUIDE.md                  # Detailed guide
├── CHANGELOG.md                    # Change history
├── CONTRIBUTING.md                 # This file
├── .gitignore                      # Git ignore
└── .dockerignore                   # Docker ignore
```

## Guidelines

### Docker Compose

- Use semantic versioning for images
- Add comments for complex configurations
- Test on clean installation
- Ensure volumes are properly configured

### Documentation

- Write clearly and concisely
- Add code examples
- Use emoji for better readability (but in moderation)
- Check links - do they work?
- Formatting: use markdown lint

### Scripts (bash)

- Add comments
- Check for errors (`set -e`)
- Use functions for reusable code
- Test on different systems (macOS, Linux)

### Security

- **NEVER** commit `.env` with real passwords
- **NEVER** hardcode passwords in files
- Use strong default values
- Document security requirements

## Testing

Before submitting PR, test:

1. **Fresh installation**
   ```bash
   # Remove everything
   make clean-all
   
   # Run setup
   ./setup.sh
   
   # Start
   make start
   
   # Check logs
   make logs
   ```

2. **Check if:**
   - All containers start properly
   - Graylog is accessible on localhost:9000
   - Login works
   - Documentation is up to date
   - Examples work

3. **Test on clean system**
   - If possible, test on clean VM or container

## Code Style

### Bash scripts

```bash
#!/bin/bash

# Use set -e for automatic error handling
set -e

# Comment complex sections
# This function does X, Y, Z

# Use uppercase for exported/env vars
MONGODB_PASSWORD="secret"

# Use lowercase for local variables
local_var="value"

# Check if commands exist
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed"
    exit 1
fi
```

### YAML (docker-compose)

```yaml
version: '3.8'

services:
  service-name:
    image: image:tag  # Always specify tag
    container_name: descriptive_name
    restart: unless-stopped  # Or 'always' for production
    networks:
      - network_name
    volumes:
      - volume_name:/path  # Named volumes
    environment:
      - VAR_NAME=${ENV_VAR}  # From .env
    # Comments to explain complex options
```

### Markdown

- Use headers hierarchically (h1 -> h2 -> h3)
- Add empty lines between sections
- Code blocks with specified language
- Use lists for enumerations
- Emoji at section start (optional)

## Code Review

Your PR will be reviewed for:

- ✅ Does it work?
- ✅ Is it well tested?
- ✅ Is documentation up to date?
- ✅ Is code readable?
- ✅ Does it maintain security?
- ✅ Does it introduce breaking changes?

## Contact

- GitHub Issues - preferred way
- Email - only for private/security issues

## License

By submitting a PR, you agree that your code will be under the same license as the project (see [LICENSE](LICENSE)).

---

## Thank You! 🙏

Every contribution, regardless of size, is appreciated!
