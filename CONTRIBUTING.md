# Contributing to Momentum

Thank you for your interest in contributing to Momentum! This guide will help you get started with development and understand our workflow.

## 🎯 Ways to Contribute

- 🐛 **Bug Reports**: Found an issue? Report it with details
- 💡 **Feature Requests**: Have ideas? We'd love to hear them
- 📝 **Documentation**: Help improve docs and guides
- 🔧 **Code Contributions**: Fix bugs, add features, improve performance
- 🎨 **UI/UX Improvements**: Make the app more user-friendly
- 🧪 **Testing**: Write tests, test on different platforms
- 🌍 **Localization**: Help translate the app

## 🚀 Getting Started

### 1. Fork & Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/momentum.git
cd momentum

# Add upstream remote to stay updated
git remote add upstream https://github.com/ORIGINAL_OWNER/momentum.git
```

### 2. Development Setup

Follow the [Installation Guide](docs/INSTALLATION.md) to set up your development environment.

**Quick Setup**:

```bash
# Backend
cd backend
npm install
cp .env.example .env  # Configure environment
npm run dev

# Frontend (new terminal)
cd ../
flutter pub get
flutter run
```

### 3. Create a Branch

```bash
# Create and switch to a new branch
git checkout -b feature/your-feature-name

# Branch naming conventions:
# feature/add-dark-mode-toggle
# bugfix/fix-login-validation
# docs/update-api-documentation
# refactor/improve-state-management
```

## 🔧 Development Standards

### Code Style

**Flutter/Dart**:

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Format code with `dart format .`
- Use meaningful variable and function names
- Add documentation comments for public APIs

```dart
// ✅ Good
/// Completes a task and updates the UI state.
/// 
/// Returns true if the task was successfully completed.
Future<bool> completeTask(String taskId, bool isCompleted) async {
  try {
    await _taskService.completeTask(taskId, isCompleted);
    _updateLocalState();
    return true;
  } catch (e) {
    _logger.e('Error completing task', error: e);
    return false;
  }
}

// ❌ Bad
Future<bool> ct(String id, bool c) async {
  await _taskService.completeTask(id, c);
  return true;
}
```

**Node.js/JavaScript**:

- Use ES6+ features and async/await
- Follow consistent indentation (2 spaces)
- Use descriptive variable names
- Add JSDoc comments for functions
- Handle errors properly with try-catch

```javascript
// ✅ Good
/**
 * Creates a new task with validation and notification
 * @param {Object} taskData - The task information
 * @param {string} userId - ID of the user creating the task
 * @returns {Promise<Task>} The created task
 */
const createTask = async (taskData, userId) => {
  try {
    const validatedData = validateTaskInput(taskData);
    const task = await Task.create({ ...validatedData, assignedBy: userId });
    await sendTaskNotification(task);
    return task;
  } catch (error) {
    logger.error('Task creation failed', error);
    throw new Error(`Failed to create task: ${error.message}`);
  }
};

// ❌ Bad
const createTask = (data, uid) => {
  const task = Task.create(data);
  return task;
};
```

### File Organization

**Frontend Structure**:

```
lib/
├── components/          # Reusable UI widgets
├── pages/              # Screen-level pages
├── models/             # Data models and DTOs
├── services/           # API services and external integrations
├── database/           # State management (TaskDatabase)
├── constants/          # App-wide constants
├── theme/             # Theme configuration
└── util/              # Helper functions and utilities
```

**Backend Structure**:

```
backend/
├── controllers/        # Request handlers and route logic
├── models/            # Mongoose schemas and models
├── services/          # Business logic and external services
├── middleware/        # Express middleware functions
├── routes/           # API route definitions
└── util/             # Helper functions and utilities
```

### Commit Standards

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```bash
# Format: <type>[optional scope]: <description>

# Examples:
git commit -m "feat: add dark mode toggle to settings page"
git commit -m "fix: resolve login validation error handling"
git commit -m "docs: update API endpoints documentation"
git commit -m "refactor(auth): improve token validation logic"
git commit -m "test: add unit tests for task completion"
git commit -m "chore: update dependencies to latest versions"
```

**Commit Types**:

- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring without feature changes
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates

## 🧪 Testing

### Running Tests

**Flutter Tests**:

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/models/task_test.dart
```

**Backend Tests**:

```bash
cd backend

# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run specific test
npm test -- --grep "Task creation"
```

### Writing Tests

**Flutter Widget Tests**:

```dart
testWidgets('TaskTile shows completion status correctly', (tester) async {
  const task = Task(
    id: 'test-id',
    name: 'Test Task',
    isCompleted: true,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: TaskTile(task: task),
    ),
  );

  expect(find.byIcon(Icons.check_circle), findsOneWidget);
  expect(find.text('Test Task'), findsOneWidget);
});
```

**Backend API Tests**:

```javascript
describe('POST /tasks', () => {
  it('should create a new task with valid data', async () => {
    const taskData = {
      name: 'Test Task',
      description: 'Test Description'
    };

    const response = await request(app)
      .post('/tasks')
      .set('Authorization', `Bearer ${validToken}`)
      .send(taskData)
      .expect(201);

    expect(response.body.task.name).toBe('Test Task');
    expect(response.body.task.assignedBy).toBe(testUserId);
  });

  it('should return 400 for missing required fields', async () => {
    const response = await request(app)
      .post('/tasks')
      .set('Authorization', `Bearer ${validToken}`)
      .send({})
      .expect(400);

    expect(response.body.message).toContain('name is required');
  });
});
```

## 📝 Documentation Standards

### Code Documentation

**Flutter/Dart Documentation**:

```dart
/// A widget that displays a task with completion status and actions.
///
/// The [TaskTile] shows task information and provides controls for
/// completing, editing, and deleting tasks.
///
/// Example usage:
/// ```dart
/// TaskTile(
///   task: myTask,
///   onToggle: (completed) => handleTaskToggle(completed),
///   onEdit: () => showEditDialog(),
///   onDelete: () => deleteTask(),
/// )
/// ```
class TaskTile extends StatefulWidget {
  /// The task to display
  final Task task;
  
  /// Callback when task completion is toggled
  final Function(bool) onToggle;
  
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
  });
}
```

**Backend API Documentation**:

```javascript
/**
 * Creates a new task
 * 
 * @route POST /tasks
 * @access Private
 * @param {Object} req.body - Task creation data
 * @param {string} req.body.name - Task name (required)
 * @param {string} [req.body.description] - Task description
 * @param {string} [req.body.priority] - Task priority (low, medium, high, urgent)
 * @param {Date} [req.body.dueDate] - Task due date
 * @param {string[]} [req.body.assignedTo] - Array of user IDs to assign
 * @returns {Object} Created task object
 * 
 * @example
 * POST /tasks
 * {
 *   "name": "Complete API documentation",
 *   "description": "Write comprehensive API docs",
 *   "priority": "high",
 *   "dueDate": "2023-12-31T23:59:59.000Z"
 * }
 */
export const createTask = async (req, res) => {
  // Implementation...
};
```

### README Updates

When adding features, update relevant documentation:

- Main [README.md](README.md) for major features
- [API Documentation](docs/API.md) for new endpoints
- [Architecture Guide](docs/ARCHITECTURE.md) for structural changes

## 🔍 Code Review Process

### Before Submitting

1. **Self-Review Checklist**:
   - [ ] Code follows style guidelines
   - [ ] All tests pass
   - [ ] No compiler warnings
   - [ ] Documentation updated
   - [ ] No hardcoded secrets or URLs
   - [ ] Error handling implemented
   - [ ] Logging added where appropriate

2. **Run Quality Checks**:

   ```bash
   # Flutter
   flutter analyze
   flutter test
   dart format . --set-exit-if-changed
   
   # Backend
   npm run lint
   npm test
   ```

### Pull Request Guidelines

**PR Title**: Use descriptive titles that explain the change

```
✅ Good: "Add team invitation expiration and cleanup"
❌ Bad: "Fix stuff"
```

**PR Description Template**:

```markdown
## 📝 Description
Brief description of changes and motivation.

## 🎯 Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## 🧪 Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## 📸 Screenshots (if applicable)
Add screenshots for UI changes.

## 📋 Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
```

### Review Criteria

**Code Quality**:

- Readable and maintainable
- Follows established patterns
- Proper error handling
- Appropriate comments

**Functionality**:

- Solves the intended problem
- Doesn't break existing features
- Handles edge cases
- Good user experience

**Testing**:

- Adequate test coverage
- Tests are meaningful
- All tests pass

## 🐛 Issue Guidelines

### Bug Reports

Use the bug report template:

```markdown
**🐛 Bug Description**
A clear and concise description of what the bug is.

**🔄 Steps to Reproduce**
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**✅ Expected Behavior**
A clear and concise description of what you expected to happen.

**📱 Environment**
- Platform: [e.g., Android, iOS, Web]
- Version: [e.g., 0.5.1]
- Device: [e.g., Pixel 6, iPhone 13]
- OS: [e.g., Android 12, iOS 15]

**📸 Screenshots**
If applicable, add screenshots to help explain your problem.

**📋 Additional Context**
Add any other context about the problem here.
```

### Feature Requests

```markdown
**💡 Feature Request**
A clear and concise description of what you want to happen.

**🎯 Problem Statement**
Is your feature request related to a problem? Please describe.

**💭 Proposed Solution**
Describe the solution you'd like.

**🔀 Alternatives Considered**
Describe any alternative solutions or features you've considered.

**📋 Additional Context**
Add any other context or screenshots about the feature request here.
```

## 🏷️ Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- `MAJOR.MINOR.PATCH` (e.g., `1.2.3`)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. **Pre-release**:
   - [ ] All tests pass
   - [ ] Documentation updated
   - [ ] CHANGELOG.md updated
   - [ ] Version numbers bumped

2. **Release**:
   - [ ] Create release branch
   - [ ] Final testing on all platforms
   - [ ] Create GitHub release
   - [ ] Deploy to production
   - [ ] Update deployment documentation

## 💬 Community Guidelines

### Code of Conduct

- **Be respectful**: Treat everyone with kindness and respect
- **Be inclusive**: Welcome newcomers and different perspectives
- **Be collaborative**: Work together to solve problems
- **Be constructive**: Provide helpful feedback and suggestions
- **Be patient**: Help others learn and grow

### Communication

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions, ideas, and general discussion
- **Pull Requests**: For code contributions and reviews

### Getting Help

- 📖 **Documentation**: Start with our comprehensive docs
- 🐛 **Issues**: Search existing issues before creating new ones
- 💬 **Discussions**: Ask questions in GitHub Discussions
- 📧 **Email**: For security issues or private concerns

## 🎉 Recognition

Contributors are recognized in:

- GitHub contributor graphs
- Release notes for significant contributions
- README acknowledgments for major features

Thank you for contributing to Momentum! 🚀

---

**Questions?**

- 💬 [GitHub Discussions](../../discussions)
- 📖 [Documentation](docs/)
- 🐛 [Report Issues](../../issues)
