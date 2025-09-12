# Contributing to EasiBites

Thank you for your interest in contributing to EasiBites! We welcome contributions from the community and are pleased to have you join us.

## 📋 Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)

## 🤝 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [conduct@easibites.com](mailto:conduct@easibites.com).

## 🚀 Getting Started

### Types of Contributions

We welcome many types of contributions:
- 🐛 Bug fixes
- ✨ New features
- 📝 Documentation improvements
- 🎨 UI/UX enhancements
- 🧪 Test coverage improvements
- 🔧 Performance optimizations
- 🌐 Translations and internationalization

### Before You Start

1. Check if there's already an [issue](https://github.com/yourusername/easibites-flutter-app/issues) for your contribution
2. For major changes, please open an issue first to discuss what you would like to change
3. Look at the [project roadmap](README.md#roadmap) to understand our direction

## 💻 Development Setup

### Prerequisites
- Flutter SDK 3.7.2+
- Dart SDK 3.0+
- Android Studio / VS Code with Flutter extensions
- Git

### Local Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/yourusername/easibites-flutter-app.git
   cd easibites-flutter-app
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Environment Configuration**
   ```bash
   cp .env.example .env
   # Update .env with your configuration
   ```

4. **Verify Setup**
   ```bash
   flutter doctor
   flutter test
   ```

## 🔄 Making Changes

### Branch Naming Convention
- `feature/description` - New features
- `bugfix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring
- `test/description` - Test improvements

### Development Workflow

1. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Follow our [coding standards](#coding-standards)
   - Add tests for new functionality
   - Update documentation as needed

3. **Test Your Changes**
   ```bash
   # Run all tests
   flutter test
   
   # Check formatting
   dart format --set-exit-if-changed .
   
   # Analyze code
   flutter analyze
   ```

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

### Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(auth): add social login with Google
fix(allergen): resolve detection accuracy issue
docs(readme): update installation instructions
```

## 📤 Submitting Changes

### Pull Request Process

1. **Push Your Branch**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request**
   - Use our PR template
   - Provide clear description of changes
   - Link related issues
   - Add screenshots for UI changes

3. **PR Requirements**
   - [ ] All tests pass
   - [ ] Code follows style guidelines
   - [ ] Documentation updated
   - [ ] No merge conflicts
   - [ ] Appropriate labels added

### Review Process

1. **Automated Checks**
   - CI/CD pipeline runs tests
   - Code quality analysis
   - Security vulnerability scan

2. **Manual Review**
   - Code review by maintainers
   - Testing on different devices
   - User experience validation

3. **Approval and Merge**
   - Requires approval from at least one maintainer
   - Squash and merge for clean history

## 📏 Coding Standards

### Dart/Flutter Guidelines

1. **Follow Official Guidelines**
   - [Effective Dart](https://dart.dev/guides/language/effective-dart)
   - [Flutter Style Guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo)

2. **Code Formatting**
   ```bash
   dart format .
   ```

3. **Linting**
   ```bash
   flutter analyze
   ```

### Project-Specific Standards

1. **File Organization**
   ```
   lib/
   ├── models/          # Data models
   ├── screens/         # UI screens
   ├── widgets/         # Reusable components
   ├── services/        # Business logic
   └── utils/           # Utility functions
   ```

2. **Naming Conventions**
   - Files: `snake_case.dart`
   - Classes: `PascalCase`
   - Variables/Functions: `camelCase`
   - Constants: `SCREAMING_SNAKE_CASE`

3. **Documentation**
   ```dart
   /// Calculates the safety score for a menu item.
   ///
   /// Returns a score between 0.0 and 1.0 where:
   /// - 1.0 = completely safe
   /// - 0.0 = contains allergens
   double calculateSafetyScore(MenuItem item, List<String> allergens) {
     // Implementation
   }
   ```

## 🧪 Testing Guidelines

### Test Types

1. **Unit Tests** (`test/`)
   ```dart
   void main() {
     group('AllergenDetector', () {
       test('should detect common allergens', () {
         // Test implementation
       });
     });
   }
   ```

2. **Widget Tests**
   ```dart
   void main() {
     testWidgets('LoginPage should display login form', (tester) async {
       // Widget test implementation
     });
   }
   ```

3. **Integration Tests** (`integration_test/`)
   ```dart
   void main() {
     group('End-to-end tests', () {
       testWidgets('Complete user journey', (tester) async {
         // E2E test implementation
       });
     });
   }
   ```

### Test Requirements

- **Coverage**: Aim for >80% code coverage
- **Performance**: Tests should run in <30 seconds
- **Reliability**: Tests must be deterministic
- **Documentation**: Complex tests need comments

### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/models/activity_model_test.dart

# Integration tests
flutter test integration_test/

# Coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 📖 Documentation

### Required Documentation

1. **Code Comments**
   - Public APIs must have documentation comments
   - Complex algorithms need explanation
   - Non-obvious code requires clarification

2. **README Updates**
   - New features added to feature list
   - Installation steps updated if needed
   - Examples provided for new functionality

3. **API Documentation**
   - New endpoints documented
   - Request/response examples
   - Error scenarios covered

### Documentation Standards

- Use clear, concise language
- Provide examples where helpful
- Include diagrams for complex flows
- Keep documentation up-to-date with code changes

## 🏷️ Issue and PR Labels

### Issue Labels
- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Improvements to documentation
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed
- `question` - Further information requested

### Priority Labels
- `priority-high` - Critical issues
- `priority-medium` - Important issues
- `priority-low` - Nice to have

### Status Labels
- `status-blocked` - Blocked by dependencies
- `status-in-progress` - Currently being worked on
- `status-review` - Needs review

## 📞 Getting Help

### Communication Channels

- **Discord**: [Join our server](https://discord.gg/easibites)
- **Email**: [developers@easibites.com](mailto:developers@easibites.com)
- **Issues**: [GitHub Issues](https://github.com/yourusername/easibites-flutter-app/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/easibites-flutter-app/discussions)

### Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [GetX Documentation](https://github.com/jonataslaw/getx)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)

## 🎉 Recognition

Contributors are recognized in:
- README.md contributors section
- Release notes for significant contributions
- Special recognition for outstanding contributions
- Opportunities to become project maintainers

## 📋 Checklist for Contributors

Before submitting a contribution:

- [ ] I have read and understood the contributing guidelines
- [ ] I have checked for existing issues/PRs related to this contribution
- [ ] I have followed the coding standards and conventions
- [ ] I have added/updated tests for my changes
- [ ] I have updated documentation as needed
- [ ] I have tested my changes on multiple devices/platforms
- [ ] My commit messages follow the conventional commit format
- [ ] I have signed the Contributor License Agreement (if required)

Thank you for contributing to EasiBites! 🍽️

---

*For any questions about contributing, please reach out to our team at [contributors@easibites.com](mailto:contributors@easibites.com)*