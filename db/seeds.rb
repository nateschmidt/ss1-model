# Variables
[
  { key: "fund_size",                      label: "Fund Size",                       value: 7_500_000 },
  { key: "investment_advisory_ratio",      label: "Investment / Advisory Ratio",     value: 1 },
  { key: "finders_fee",                    label: "Finder's Fee",                    value: 2 },
  { key: "pooled_consortium",              label: "Pooled Consortium",               value: 5 },
  { key: "consortium_members",             label: "Consortium Members",              value: 7 },
  { key: "founders_option_pool",           label: "Founders Option Pool",            value: 60 },
  { key: "founders_option_pool_exercised", label: "Founders Option Pool Exercised",  value: 100 },
  { key: "total_companies",               label: "Total Companies Launched",         value: 7 },
].each do |attrs|
  Variable.find_or_initialize_by(key: attrs[:key]).update!(attrs)
end

# Entities
entities = [
  { name: "Member 1", entity_type: "consortium", investment: 2_500_000, finders_fee_count: 0, position: 1 },
  { name: "Member 2", entity_type: "consortium", investment: 1_000_000, finders_fee_count: 0, position: 2 },
  { name: "Member 3", entity_type: "consortium", investment: 0,         finders_fee_count: 0, position: 3 },
  { name: "Member 4", entity_type: "consortium", investment: 0,         finders_fee_count: 0, position: 4 },
  { name: "Member 5", entity_type: "consortium", investment: 0,         finders_fee_count: 0, position: 5 },
  { name: "Member 6", entity_type: "consortium", investment: 0,         finders_fee_count: 0, position: 6 },
  { name: "Member 7", entity_type: "consortium", investment: 0,         finders_fee_count: 0, position: 7 },
  { name: "Investors", entity_type: "investor",  investment: 4_000_000, finders_fee_count: 0, position: 8 },
  { name: "Alloy Partners", entity_type: "operator", investment: 0,     finders_fee_count: 0, position: 9 },
]

entities.each do |attrs|
  Entity.find_or_initialize_by(name: attrs[:name]).update!(attrs)
end
