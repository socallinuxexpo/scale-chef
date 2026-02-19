context = ChefCLI::Generator.context
cookbook_dir = File.join(context.cookbook_root, context.cookbook_name)

silence_chef_formatter unless context.verbose

generator_desc('Ensuring correct cookbook content')

# cookbook root dir
directory cookbook_dir

# metadata.rb
spdx_license =  case context.license
                when 'apachev2'
                  'Apache-2.0'
                when 'mit'
                  'MIT'
                when 'gplv2'
                  'GPL-2.0'
                when 'gplv3'
                  'GPL-3.0'
                else
                  'All Rights Reserved'
                end

template "#{cookbook_dir}/metadata.rb" do
  helpers(ChefCLI::Generator::TemplateHelper)
  variables(
    :spdx_license => spdx_license,
  )
  action :create_if_missing
end

# README
template "#{cookbook_dir}/README.md" do
  helpers(ChefCLI::Generator::TemplateHelper)
  action :create_if_missing
end

directory "#{cookbook_dir}/attributes"

template "#{cookbook_dir}/attributes/default.rb" do
  helpers(ChefCLI::Generator::TemplateHelper)
  source 'attribute.rb.erb'
  action :create_if_missing
end

# Recipes
directory "#{cookbook_dir}/recipes"

if context.yaml
  template "#{cookbook_dir}/recipes/default.yml" do
    source 'recipe.yml.erb'
    helpers(ChefCLI::Generator::TemplateHelper)
    action :create_if_missing
  end
else
  template "#{cookbook_dir}/recipes/default.rb" do
    source 'recipe.rb.erb'
    helpers(ChefCLI::Generator::TemplateHelper)
    action :create_if_missing
  end
end
