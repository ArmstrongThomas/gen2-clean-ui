return function()
  local SharedChoiceBox = {}

  function SharedChoiceBox.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local pending = rawget(state, "pending") ~= nil
    return {
      model = {
        schema = "clean_ui.v3.presentation.v1",
        apiVersion = 3,
        screenId = "shared.ChoiceBox",
        family = "dialogue",
        preset = "XS",
        anchor = rawget(state, "anchor") == "bottom"
          and "above_dialogue" or nil,
        selected = rawget(state, "index") == 2 and 2 or 1,
        pending = pending,
        inputReady = not pending,
        options = {
          { id="yes", label="YES", value=true, sourceIndex=1,
            disabled=pending },
          { id="no", label="NO", value=false, sourceIndex=2,
            disabled=pending },
        },
      },
      actions = { screenId="shared.ChoiceBox", entries={}, order={} },
    }
  end

  function SharedChoiceBox.fixtures()
    return {{ variant="yes_no", state={ index=1, anchor="bottom" } }}
  end

  return SharedChoiceBox
end
