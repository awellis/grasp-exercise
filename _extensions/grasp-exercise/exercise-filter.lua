-- exercise-filter.lua
-- Simplified Quarto filter to extract exercise data and generate JSON

-- Global variables to store exercise data
local exercise_data = {
  metadata = {},
  first_message = "",
  end_message = "",
  checkpoints = {}
}

local current_checkpoint = nil
local current_step = nil

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
  -- Handle different div classes for exercise components
  local classes = div.classes
  
  -- Check if div has the class we're looking for
  local function hasClass(className)
    for _, class in ipairs(classes) do
      if class == className then
        return true
      end
    end
    return false
  end
  
  if hasClass("checkpoint") then
    -- Start a new checkpoint
    local checkpoint_num = div.attributes["number"] or tostring(#exercise_data.checkpoints + 1)
    current_checkpoint = {
      checkpoint_number = tonumber(checkpoint_num),
      main_question = "",
      main_answer = "",
      image_solution = div.attributes["image"] or "",
      steps = {}
    }
    table.insert(exercise_data.checkpoints, current_checkpoint)
    current_step = nil
    
  elseif hasClass("main-question") then
    if current_checkpoint then
      current_checkpoint.main_question = pandoc.utils.stringify(div.content)
    end
    
  elseif hasClass("main-answer") then
    if current_checkpoint then
      current_checkpoint.main_answer = pandoc.utils.stringify(div.content)
    end
    
  elseif hasClass("step") then
    -- Start a new step within current checkpoint
    if current_checkpoint then
      local step_num = div.attributes["number"] or tostring(#current_checkpoint.steps + 1)
      current_step = {
        step_number = tonumber(step_num),
        guiding_question = "",
        guiding_answer = "",
        image = div.attributes["image"] or ""
      }
      table.insert(current_checkpoint.steps, current_step)
    end
    
  elseif hasClass("guiding-question") then
    if current_step then
      current_step.guiding_question = pandoc.utils.stringify(div.content)
    end
    
  elseif hasClass("guiding-answer") then
    if current_step then
      current_step.guiding_answer = pandoc.utils.stringify(div.content)
    end
  end
  
  return div
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
    -- Escape quotes and handle multiline
    if string.find(value, "[:\n\"']") then
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
  
  -- Write YAML file using our simple converter
  local yaml_str = to_yaml(exercise_data)
  local yaml_file = io.open("exercise-output.yaml", "w")
  if yaml_file then
    yaml_file:write(yaml_str)
    yaml_file:close()
    print("✅ Generated exercise-output.yaml")
  end
  
  return doc
end