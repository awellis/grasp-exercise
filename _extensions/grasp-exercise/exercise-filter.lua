-- exercise-filter.lua
-- GRASP Exercise Filter with Support for Nested Div Structure
-- Processes hierarchical structure where steps are nested within checkpoints

-- Global variables to store exercise data
local exercise_data = {
  metadata = {},
  first_message = "",
  end_message = "",
  checkpoints = {}
}

local current_checkpoint = nil

function Meta(meta)
  -- Extract metadata from YAML header
  if meta.exercise then
    exercise_data.metadata = {
      title = meta.exercise.title and pandoc.utils.stringify(meta.exercise.title) or "",
      topic = meta.exercise.topic and pandoc.utils.stringify(meta.exercise.topic) or "",
      level = meta.exercise.level and pandoc.utils.stringify(meta.exercise.level) or "",
      language = meta.exercise.language and pandoc.utils.stringify(meta.exercise.language) or "",
      author = meta.exercise.author and pandoc.utils.stringify(meta.exercise.author) or "",
      tags = meta.exercise.tags or {},
      version = meta.exercise.version and pandoc.utils.stringify(meta.exercise.version) or "1.0",
      date_created = meta.exercise.date_created and pandoc.utils.stringify(meta.exercise.date_created) or os.date("%Y-%m-%d")
    }
    
    exercise_data.first_message = meta.exercise.first_message and pandoc.utils.stringify(meta.exercise.first_message) or ""
    exercise_data.end_message = meta.exercise.end_message and pandoc.utils.stringify(meta.exercise.end_message) or ""
  end
  
  return meta
end

function Div(div)
  local classes = div.classes
  
  -- Helper function to check if div has a specific class
  local function hasClass(className)
    for _, class in ipairs(classes) do
      if class == className then
        return true
      end
    end
    return false
  end
  
  -- Process checkpoint divs
  if hasClass("checkpoint") then
    local checkpoint_num = div.attributes["number"] or tostring(#exercise_data.checkpoints + 1)
    current_checkpoint = {
      checkpoint_number = tonumber(checkpoint_num),
      title = "",
      main_question = "",
      main_answer = "",
      image_solution = div.attributes["image"] or "",
      steps = {}
    }
    
    -- Add to exercise data
    table.insert(exercise_data.checkpoints, current_checkpoint)
    
    -- Process the nested content within the checkpoint
    processCheckpointContent(div.content, current_checkpoint)
    
    return div
  end
  
  -- For backward compatibility, handle flat structure as well
  -- (when divs are not nested inside checkpoints)
  if not current_checkpoint then
    return div
  end
  
  return div
end

function processCheckpointContent(content, checkpoint)
  local current_step = nil
  
  for _, block in ipairs(content) do
    if block.tag == "Div" then
      local classes = block.classes
      
      local function hasClass(className)
        for _, class in ipairs(classes) do
          if class == className then
            return true
          end
        end
        return false
      end
      
      if hasClass("main-question") then
        checkpoint.main_question = pandoc.utils.stringify(block.content)
        
      elseif hasClass("main-answer") then
        checkpoint.main_answer = pandoc.utils.stringify(block.content)
        
      elseif hasClass("step") then
        local step_num = block.attributes["number"] or tostring(#checkpoint.steps + 1)
        current_step = {
          step_number = tonumber(step_num),
          guiding_question = "",
          guiding_answer = "",
          image = block.attributes["image"] or ""
        }
        table.insert(checkpoint.steps, current_step)
        
        -- Process nested step content
        processStepContent(block.content, current_step)
      end
      
    elseif block.tag == "Header" then
      -- Extract title from header within checkpoint
      if block.level >= 3 then
        checkpoint.title = pandoc.utils.stringify(block.content)
      end
    end
  end
end

function processStepContent(content, step)
  for _, block in ipairs(content) do
    if block.tag == "Div" then
      local classes = block.classes
      
      local function hasClass(className)
        for _, class in ipairs(classes) do
          if class == className then
            return true
          end
        end
        return false
      end
      
      if hasClass("guiding-question") then
        step.guiding_question = pandoc.utils.stringify(block.content)
      elseif hasClass("guiding-answer") then
        step.guiding_answer = pandoc.utils.stringify(block.content)
      end
    end
  end
end

-- Simple function to convert Lua table to YAML format
function to_yaml(data, indent)
  indent = indent or 0
  local space = string.rep("  ", indent)
  local yaml = ""
  
  if type(data) == "table" then
    -- Check if it's an array (sequential numeric keys starting from 1)
    local is_array = true
    local array_size = 0
    for k, v in pairs(data) do
      if type(k) ~= "number" then
        is_array = false
        break
      end
      array_size = math.max(array_size, k)
    end
    
    if is_array then
      -- Handle as array
      for i = 1, array_size do
        if data[i] ~= nil then
          yaml = yaml .. space .. "-"
          if type(data[i]) == "table" then
            yaml = yaml .. "\n" .. to_yaml(data[i], indent + 1)
          else
            yaml = yaml .. " " .. format_yaml_value(data[i]) .. "\n"
          end
        end
      end
    else
      -- Handle as object
      for key, value in pairs(data) do
        yaml = yaml .. space .. key .. ":"
        if type(value) == "table" then
          yaml = yaml .. "\n" .. to_yaml(value, indent + 1)
        else
          yaml = yaml .. " " .. format_yaml_value(value) .. "\n"
        end
      end
    end
  end
  
  return yaml
end

function format_yaml_value(value)
  if type(value) == "string" then
    -- Handle multiline strings
    if string.find(value, "\n") then
      return "|\n" .. string.gsub(value, "([^\n]+)", "  %1")
    -- Escape special characters
    elseif string.find(value, "[:\n\"'%[%]{}|>]") then
      return "\"" .. string.gsub(value, "\"", "\\\"") .. "\""
    else
      return value
    end
  elseif type(value) == "number" then
    return tostring(value)
  elseif type(value) == "boolean" then
    return value and "true" or "false"
  else
    return tostring(value)
  end
end

function Pandoc(doc)
  -- Write JSON file using pandoc's built-in JSON encoder
  local json_str = pandoc.json.encode(exercise_data)
  local json_file = io.open("exercise-output.json", "w")
  if json_file then
    json_file:write(json_str)
    json_file:close()
    print("✅ Generated exercise-output.json")
  end
  
  -- Write YAML file using our custom converter
  local yaml_str = to_yaml(exercise_data)
  local yaml_file = io.open("exercise-output.yaml", "w")
  if yaml_file then
    yaml_file:write(yaml_str)
    yaml_file:close()
    print("✅ Generated exercise-output.yaml")
  end
  
  return doc
end