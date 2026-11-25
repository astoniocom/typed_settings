import 'package:json_schema_builder/json_schema_builder.dart';

/// JSON Schema for a single Todo item.
final _todoItemSchema = S.object(
  title: 'Todo',
  description: 'A single task in the todo list',
  required: ['title', 'completed'],
  additionalProperties: false,
  properties: {
    'title': S.string(
      title: 'Title',
      description: 'Short description of the task',
      minLength: 1,
      maxLength: 200,
    ),
    'completed': S.boolean(
      title: 'Completed',
      description: 'Whether the task has been finished',
    ),
    'description': S.string(
      title: 'Description',
      description: 'Detailed notes about the task',
      maxLength: 2000,
    ),
    'due_date': S.string(
      title: 'Due date',
      description: 'Deadline in ISO 8601 format',
      format: 'date',
    ),
    'priority': S.combined(
      title: 'Priority',
      description: 'Task urgency level',
      enumValues: ['low', 'medium', 'high'],
    ),
    'tags': S.list(
      title: 'Tags',
      description: 'Labels for categorization',
      items: S.string(minLength: 1, maxLength: 32),
      uniqueItems: true,
      maxItems: 10,
    ),
    'assignee': S.object(
      title: 'Assignee',
      description: 'Person responsible for the task',
      required: ['name'],
      properties: {
        'name': S.string(title: 'Name', minLength: 1),
        'email': S.string(title: 'Email', format: 'email'),
      },
    ),
    'estimated_minutes': S.integer(
      title: 'Estimated time (minutes)',
      description: 'How long the task is expected to take',
      minimum: 1,
      maximum: 480,
    ),
  },
);

/// JSON Schema for the root Todo list container, the schema of
/// `AppSettings.todoList`.
final todoListSchema = S.object(
  title: 'Todo list',
  description: 'A named collection of todo items',
  required: ['name', 'todos'],
  additionalProperties: false,
  properties: {
    'name': S.string(
      title: 'List name',
      description: 'Display name of the todo list',
      minLength: 1,
      maxLength: 100,
    ),
    'description': S.string(
      title: 'Description',
      description: 'Optional description of this list',
      maxLength: 500,
    ),
    'todos': S.list(
      title: 'Todos',
      description: 'Collection of todo items',
      items: _todoItemSchema,
    ),
  },
);
