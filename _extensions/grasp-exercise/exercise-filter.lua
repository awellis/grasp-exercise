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
local debug_mode = true -- Set to true to print debugging information

-- Helper function for debugging
local function debug_print(...)
  if debug_mode then
    print("[DEBUG]", ...)
  end
end

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

-- Helper function to check if div has a specific class
local function hasClass(classes, className)
  for _, class in ipairs(classes) do
    if class == className then
      return true
    end
  end
  return false
end

-- New function to print div structure for debugging
local function inspect_div(div, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  
  local classes_str = table.concat(div.classes, ", ")
  debug_print(prefix .. "DIV with classes: " .. classes_str)
  
  for _, block in ipairs(div.content) do
    if block.tag == "Div" then
      inspect_div(block, indent + 1)
    elseif block.tag == "Header" then
      debug_print(prefix .. "  HEADER: " .. pandoc.utils.stringify(block.content))
    elseif block.tag == "Para" then
      debug_print(prefix .. "  PARA: " .. pandoc.utils.stringify(block.content):sub(1, 30) .. "...")
    end
  end
end

function Div(div)
  local classes = div.classes
  
  -- For debugging, inspect the top-level divs
  if debug_mode and hasClass(classes, "checkpoint") then
    debug_print("INSPECTING CHECKPOINT DIV:")
    inspect_div(div, 1)
  end
  
  -- Process checkpoint divs
  if hasClass(classes, "checkpoint") then
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
    
    debug_print("Processed checkpoint", checkpoint_num, "with", #current_checkpoint.steps, "steps")
    
    return div
  end
  
  -- Process steps if they're not nested (flat structure)
  if hasClass(classes, "step") and current_checkpoint then
    local step_num = div.attributes["number"] or tostring(#current_checkpoint.steps + 1)
    local step = {
      step_number = tonumber(step_num),
      guiding_question = "",
      guiding_answer = "",
      image = div.attributes["image"] or ""
    }
    
    -- Add to current checkpoint's steps
    table.insert(current_checkpoint.steps, step)
    
    -- Process the step content
    processStepContent(div.content, step)
    
    debug_print("Processed flat step", step_num)
    
    return div
  end
  
  -- Process main-question and main-answer divs if they're not nested
  if current_checkpoint then
    if hasClass(classes, "main-question") then
      current_checkpoint.main_question = pandoc.utils.stringify(div.content)
      return div
    elseif hasClass(classes, "main-answer") then
      current_checkpoint.main_answer = pandoc.utils.stringify(div.content)
      return div
    end
  end
  
  return div
end

function findStepsInDiv(content, checkpoint)
  for _, block in ipairs(content) do
    if block.tag == "Div" then
      local classes = block.classes
      
      if hasClass(classes, "step") then
        local step_num = block.attributes["number"] or tostring(#checkpoint.steps + 1)
        debug_print("Found nested step", step_num)
        
        local step = {
          step_number = tonumber(step_num),
          guiding_question = "",
          guiding_answer = "",
          image = block.attributes["image"] or ""
        }
        
        -- Look for guiding question and answer inside step
        for _, inner_block in ipairs(block.content) do
          if inner_block.tag == "Div" then
            local inner_classes = inner_block.classes
            
            if hasClass(inner_classes, "guiding-question") then
              step.guiding_question = pandoc.utils.stringify(inner_block.content)
              debug_print("Found nested guiding question:", step.guiding_question:sub(1, 30) .. "...")
            elseif hasClass(inner_classes, "guiding-answer") then
              step.guiding_answer = pandoc.utils.stringify(inner_block.content)
              debug_print("Found nested guiding answer:", step.guiding_answer:sub(1, 30) .. "...")
            end
          end
        end
        
        -- Add to checkpoint's steps
        table.insert(checkpoint.steps, step)
      else
        -- Recursively look for steps in nested divs
        findStepsInDiv(block.content, checkpoint)
      end
    end
  end
end

function processCheckpointContent(content, checkpoint)
  for _, block in ipairs(content) do
    if block.tag == "Div" then
      local classes = block.classes
      
      if hasClass(classes, "main-question") then
        checkpoint.main_question = pandoc.utils.stringify(block.content)
        debug_print("Found main question for checkpoint", checkpoint.checkpoint_number)
        
      elseif hasClass(classes, "main-answer") then
        checkpoint.main_answer = pandoc.utils.stringify(block.content)
        debug_print("Found main answer for checkpoint", checkpoint.checkpoint_number)
      end
      
    elseif block.tag == "Header" then
      -- Extract title from header within checkpoint
      if block.level >= 3 then
        checkpoint.title = pandoc.utils.stringify(block.content)
        debug_print("Found title for checkpoint", checkpoint.checkpoint_number, ":", checkpoint.title)
      end
    end
  end
  
  -- After processing main questions and answers, now look for steps
  findStepsInDiv(content, checkpoint)
end

function processStepContent(content, step)
  for _, block in ipairs(content) do
    if block.tag == "Div" then
      local classes = block.classes
      
      if hasClass(classes, "guiding-question") then
        step.guiding_question = pandoc.utils.stringify(block.content)
        debug_print("Found guiding question for step", step.step_number)
      elseif hasClass(classes, "guiding-answer") then
        step.guiding_answer = pandoc.utils.stringify(block.content)
        debug_print("Found guiding answer for step", step.step_number)
      end
    end
  end
end

-- Simple function to convert Lua table to YAML format
function to_yaml(data, indent, key_name)
  indent = indent or 0
  key_name = key_name or ""
  local space = string.rep("  ", indent)
  local yaml = ""
  
  if type(data) == "table" then
    -- Handle special case for steps
    if key_name == "steps" and next(data) == nil then
      return " []\n"
    end
    
    -- Check if it's an array (sequential numeric keys starting from 1)
    local is_array = true
    local max_index = 0
    
    -- First determine if it's an array
    for k, _ in pairs(data) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        is_array = false
        break
      end
      max_index = math.max(max_index, k)
    end
    
    -- Handle empty tables properly
    if next(data) == nil then
      if key_name == "steps" then
        return " []\n"
      else
        return yaml
      end
    end
    
    if is_array then
      -- Handle as array
      for i = 1, max_index do
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
          if next(value) == nil and (key == "steps") then
            yaml = yaml .. " []\n"
          else
            yaml = yaml .. "\n" .. to_yaml(value, indent + 1, key)
          end
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
  
  if debug_mode then
    print("✅ Generated output with", #exercise_data.checkpoints, "checkpoints")
    for i, checkpoint in ipairs(exercise_data.checkpoints) do
      print(string.format("  - Checkpoint %d: %s (contains %d steps)", 
                         checkpoint.checkpoint_number, 
                         checkpoint.title, 
                         #checkpoint.steps))
    end
  end
  
  return doc
end