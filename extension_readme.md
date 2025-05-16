# Quarto Exercise Extension

## Directory Structure
```
_extensions/
  exercise-maker/
    _extension.yml
    exercise-filter.lua
    exercise-schema.json
    validate-exercise.py
```

## Installation and Usage

1. Copy the extension to your `_extensions/exercise-maker/` directory
2. In your qmd file, add the extension to the YAML header:

```yaml
---
title: "My Exercise"
format: html
filters:
  - exercise-maker
exercise:
  title: "Introduction to Statistics"
  topic: "ANOVA"
  level: "intermediate"
  language: "en"
  author: "Your Name"
  tags: ["statistics", "anova"]
  first_message: "Welcome to this statistics exercise..."
  end_message: "Congratulations! You've completed the exercise."
---
```

3. Use the provided div classes in your markdown to structure the exercise:

```markdown
::: {.checkpoint number="1" image="static/chart1.png"}
:::

::: {.main-question}
What is the main research question we're investigating?
:::

::: {.main-answer}
We're investigating whether sleep duration affects reaction time...
:::

::: {.step number="1" image="static/step1.png"}
:::

::: {.guiding-question}
What is the difference between ANOVA types?
:::

::: {.guiding-answer}
Between-subjects ANOVA compares different groups...
:::
```

## Features

- ✅ Validates exercise structure
- ✅ Generates both YAML and JSON output
- ✅ Preserves images and formatting
- ✅ Easy to write and maintain
- ✅ Integrates seamlessly with Quarto