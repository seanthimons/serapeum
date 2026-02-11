# Security Policy

## Reporting a Vulnerability

The Serapeum team takes security vulnerabilities seriously. We appreciate your efforts to responsibly disclose your findings.

### How to Report

If you discover a security vulnerability, please report it by:

1. **Do not** open a public GitHub issue
2. Instead, open a private security advisory at:
   - Go to the repository's Security tab
   - Click "Report a vulnerability"
   - Fill out the security advisory form

Alternatively, you can create a regular issue and mark it as a security concern, but we prefer the private security advisory route for sensitive issues.

### What to Include

When reporting a vulnerability, please include:

- **Description** - A clear description of the vulnerability
- **Impact** - What could an attacker accomplish?
- **Steps to reproduce** - Detailed steps to reproduce the issue
- **Affected versions** - Which versions are vulnerable?
- **Proposed fix** - If you have suggestions for fixing the issue
- **Proof of concept** - Code or screenshots demonstrating the issue (if applicable)

### Response Timeline

- **Initial response** - We aim to respond within 48 hours
- **Status updates** - We will provide updates on progress every 5-7 days
- **Resolution** - We aim to resolve critical issues within 30 days

### What to Expect

1. **Acknowledgment** - We will acknowledge receipt of your report
2. **Investigation** - We will investigate and validate the issue
3. **Fix development** - We will develop and test a fix
4. **Disclosure** - We will coordinate disclosure timing with you
5. **Credit** - We will credit you in the security advisory (if desired)

## Security Best Practices

### For Users

When deploying Serapeum:

- **Protect API keys** - Store API keys securely in `config.yml` (which is gitignored)
- **Keep dependencies updated** - Regularly update R packages
- **Review permissions** - Limit file system access appropriately
- **Use HTTPS** - Deploy behind HTTPS in production
- **Secure the database** - Restrict access to `data/notebooks.duckdb`
- **Validate uploads** - Be cautious with uploaded PDFs from untrusted sources

### For Developers

When contributing code:

- **No hardcoded secrets** - Never commit API keys or credentials
- **Input validation** - Validate and sanitize all user inputs
- **SQL injection prevention** - Use parameterized queries (DuckDB driver handles this)
- **XSS prevention** - Sanitize HTML output in Shiny
- **Path traversal** - Validate file paths to prevent directory traversal
- **Dependency security** - Review dependencies for known vulnerabilities

## Known Security Considerations

### Local-First Architecture

Serapeum is designed as a **local-first, self-hosted** application:

- **Data privacy** - All data is stored locally in `data/notebooks.duckdb`
- **No cloud storage** - Uploaded documents stay on your machine
- **API key control** - You control which API providers to use

### Third-Party API Usage

Serapeum integrates with external APIs:

- **OpenRouter** - For LLM access (chat and embeddings)
- **OpenAlex** - For academic paper search
- **PDF processing** - Local PDF parsing (pdftools)

**Important**: Data sent to these APIs may be logged or processed according to their privacy policies. Review their terms before use:
- [OpenRouter Privacy](https://openrouter.ai/privacy)
- [OpenAlex Terms](https://openalex.org/terms)

### AI-Generated Content

As noted in the README disclaimer:
- AI responses may contain errors or hallucinations
- Always verify important information from primary sources
- Not a substitute for professional advice
- Critical decisions should be based on manual review

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < main  | :x:                |

Currently, only the latest version on the `main` branch is actively supported. We recommend always running the latest version.

## Security Updates

Security updates will be:
- Released as soon as possible after a fix is available
- Announced in the CHANGELOG (if applicable)
- Tagged with security advisory details
- Communicated through GitHub Security Advisories

## Questions?

If you have questions about security:
- Check this SECURITY.md document
- Review the [Code of Conduct](CODE_OF_CONDUCT.md)
- Open a general issue (for non-sensitive questions)

Thank you for helping keep Serapeum secure!
