require 'jcheck_rails/encoder'

module JcheckRails
  class Engine < Rails::Engine
    rake_tasks do
      load File.expand_path('../../tasks/jcheck_tasks.rake', __FILE__)
    end
  end
  
  extend self
  
  KNOW_VALIDATORS = [:acceptance, :confirmation, :exclusion, :format, :inclusion, :length, :numericality, :presence]
  
  # This will reflect into your model and generate correct jCheck validations
  # for you. In first argument you should send the current object of model, if
  # you want to get just the validations for an given attribute, send the
  # attribute name as second parameter. In third parameter you can send options
  # to be used in jCheck initialization, but there some special keys that can
  # be sent in the options. You can also send options as second parameter, in
  # this case the attribute will be considered nil.
  #
  #   <%= form_for(@object) do |f| %>
  #     ...
  #   <% end %>
  #   <%= jcheck_for(@object) %>
  #
  # Configuration options:
  # * <tt>:variable</tt> - Variable name to be used in javascript (default is: "validator")
  # * <tt>:form_id</tt> - The id of form in html to be used in jQuery selector (default is same behaviour as +form_for+ do to generate form id)
  # * <tt>:field_prefix</tt> - Field prefix to be used into jCheck, send nil to avoid field_prefix (default is same prefix as form_for will do)
  # * <tt>:generate_field_names</tt> - Define if it should generate field custom_label for jCheck (default is true)
  # * <tt>:only_attributes</tt> - Filter the attributes that should be reflected (default nil)
  # * <tt>:exclude_attributes</tt> - Filter the attributes that should not be reflected (default nil)
  #
  # Also, any other configuration option will be sent to jCheck() initializer.
  #
  def jcheck_for(*args)
    options = args.extract_options!
    object = args.shift
    attribute = args.length > 0 ? args[0] : nil
    
    return jcheck_for_object_attribute(object, attribute) if attribute
    
    options.reverse_merge!(
      :variable => "validator",
      :form_id => ActionController::RecordIdentifier.dom_id(object, (object.respond_to?(:persisted?) && object.persisted? ? :edit : nil)),
      :field_prefix => ActiveModel::Naming.singular(object),
      :generate_field_names => true,
      :only_attributes => nil,
      :exclude_attributes => nil
    )
    
    only_attributes = options.delete :only_attributes
    exclude_attributes = options.delete :exclude_attributes
    variable = options.delete :variable
    form_id = options.delete :form_id
    generate_field_names = options.delete :generate_field_names
    
    validations = []
    field_names = []
    
    object.class._validators.each do |attribute, validators|
      next if only_attributes and !(only_attributes.include?(attribute))
      next if exclude_attributes and exclude_attributes.include?(attribute)
      
      attr_validations = jcheck_for_object_attribute(object, attribute)
      
      field_names << "#{variable}.field(#{Encoder.convert_to_javascript attribute}).custom_label = #{Encoder.convert_to_javascript jcheck_attribute_name(object, attribute)};" if generate_field_names
      validations << "#{variable}.validates(#{Encoder.convert_to_javascript attribute}, #{attr_validations});"
    end
    
    %{<script type="text/javascript"> jQuery(function() { var #{variable} = jQuery('##{form_id}').jcheck(#{Encoder.convert_to_javascript(options)}); #{validations.join(" ")} #{field_names.join(" ")} }); </script>}.html_safe
  end
  
  def jcheck_attribute_name(object, attribute)
    if object.class.respond_to? :human_attribute_name
      object.class.human_attribute_name(attribute)
    else
      attribute.to_s.humanize
    end
  end
  
  def jcheck_for_object_attribute(object, attribute)
    validations = object.class._validators[attribute].inject([]) do |acc, validator|
      options = filter_validator_options(validator)
      
      acc << "#{Encoder.convert_to_javascript validator.kind}: #{Encoder.convert_to_javascript(options)}" if KNOW_VALIDATORS.include? validator.kind
      acc
    end
    
    "{#{validations.join(', ')}}"
  end
  
  protected
  
  def filter_validator_options(validator)
    options = validator.options.dup
    
    case validator.kind
    when :acceptance
      options.delete :allow_nil
    when :length
      options.delete :tokenizer
    end
    
    options
  end
end

ActionView::Base.send :include, JcheckRails
