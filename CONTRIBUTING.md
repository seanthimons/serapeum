# Contributing to Serapeum

Thank you for your interest in contributing to Serapeum! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project adheres to the Contributor Covenant [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior through the repository's issue tracker.

## Getting Started

### Prerequisites

- R >= 4.0
- Required R packages (see `app.R` for dependencies)
- OpenRouter API key (for LLM access)
- OpenAlex API key (optional, for enhanced rate limits)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/seanthimons/serapeum.git
   cd serapeum
   ```

2. Copy the example config:
   ```bash
   cp config.example.yml config.yml
   ```

3. Add your API keys to `config.yml`

4. Install R dependencies (they will be installed automatically when you run the app)

5. Run the app:
   ```r
   shiny::runApp()
   ```

## How to Contribute

### Reporting Bugs

- Use the GitHub issue tracker
- Check if the issue already exists before creating a new one
- Include as much detail as possible:
  - Steps to reproduce
  - Expected behavior
  - Actual behavior
  - R version and OS
  - Error messages and stack traces

### Suggesting Features

- Open an issue with the "Feature Request" label
- Describe the feature and its use case
- Explain why this feature would be useful to the community
- Check `TODO.md` for the current roadmap

### Contributing Code

1. Check existing issues or create a new one to discuss your contribution
2. Fork the repository
3. Create a feature branch from `main`
4. Make your changes
5. Test your changes
6. Submit a pull request

## Development Workflow

### Branch Naming

Use descriptive branch names with prefixes:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test additions or modifications

Example: `feature/add-citation-export`

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb in present tense (e.g., "Add", "Fix", "Update")
- Keep the first line under 72 characters
- Provide additional context in the body if needed

Example:
```
Add citation export functionality

Implements BibTeX and RIS export for papers in search notebooks.
Adds export buttons to the UI and helper functions for format conversion.
```

## Pull Request Process

1. **Create a feature branch** - Never commit directly to `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** - Follow the coding standards

3. **Test your changes** - Run the test suite
   ```r
   testthat::test_dir("tests/testthat")
   ```

4. **Update documentation** - Update README.md, TODO.md, or other docs if needed

5. **Commit and push** - Push your branch to your fork
   ```bash
   git add .
   git commit -m "Your commit message"
   git push origin feature/your-feature-name
   ```

6. **Open a pull request** - Create a PR from your branch to `main`
   - Fill out the PR template
   - Reference any related issues
   - Provide a clear description of your changes
   - Include screenshots for UI changes

7. **Address feedback** - Respond to review comments and make requested changes

8. **Merge** - Once approved, your PR will be merged

## Coding Standards

### R Code Style

- Follow the [Tidyverse Style Guide](https://style.tidyverse.org/)
- Use 2 spaces for indentation (not tabs)
- Use `<-` for assignment, not `=`
- Use snake_case for function and variable names
- Keep functions focused and single-purpose
- Add comments for complex logic

### Shiny Module Structure

- All Shiny modules should follow the existing pattern in `R/mod_*.R`
- Use `moduleServer()` for server logic
- Namespace all inputs/outputs with the module ID
- Document module parameters

### Code Organization

- Place Shiny modules in `R/mod_*.R`
- Place utility functions in appropriate `R/*.R` files
- Place API clients in `R/api_*.R`
- Place tests in `tests/testthat/test-*.R`

### Comments

- Add comments to explain "why", not "what"
- Document complex algorithms or business logic
- Use roxygen2 comments for functions that will be reused

## Testing

### Running Tests

Run all tests:
```r
testthat::test_dir("tests/testthat")
```

Run a specific test file:
```r
testthat::test_file("tests/testthat/test-db.R")
```

### Writing Tests

- Place tests in `tests/testthat/test-*.R`
- Use descriptive test names
- Test edge cases and error conditions
- Mock external API calls when possible
- Ensure tests are independent and can run in any order

Example:
```r
test_that("parse_config returns valid config structure", {
  config <- parse_config("config.example.yml")
  expect_type(config, "list")
  expect_true("openrouter" %in% names(config))
})
```

## Documentation

### README Updates

- Update README.md if you add new features
- Keep the feature list current
- Update setup instructions if needed

### Code Documentation

- Add comments for complex logic
- Document function parameters and return values
- Update inline documentation when changing function signatures

### Design Documents

For significant features, create a design document in `docs/plans/`:
- Describe the problem and proposed solution
- Include implementation details
- Discuss trade-offs and alternatives

## Questions?

If you have questions or need help:
- Check existing issues and documentation
- Open a new issue with your question
- Tag it with the "question" label

## Thank You!

Your contributions make Serapeum better for everyone. We appreciate your time and effort!
