ActiveSupport.on_load(:action_controller) do
  wrap_parameters format: []
end
 
ActiveSupport.on_load(:active_record) do
  self.include_root_in_json = true
end