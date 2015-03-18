require "elasticsearch"
require "haml"
require "./haml_helpers"
require "yaml"

client = Elasticsearch::Client.new log: false

client.transport.reload_connections!
client.cluster.health

stats = {}

## GROWTH

# profiles

%w(artists promoters).each do |profile_type|
  stats["total_#{profile_type}"] = client.count(index: "gigmit_production_#{profile_type}", body: {
    query:{
      filtered: {
        filter: {
          bool: {
            must: {
              missing: {field: 'destroyed_at'}
            }
          }
        }
      }
    }
  })['count']

  stats["#{profile_type}_histogram"] = client.search(index: "gigmit_production_#{profile_type}", body: {
    aggs: {
      profiles_over_time: {
        date_histogram: {
          field: "created_at",
          interval: "week",
          min_doc_count: 0
        }
      }
    }
  })["aggregations"]["profiles_over_time"]["buckets"].map{|bucket| bucket_date = Date.parse(bucket["key_as_string"]); {year: bucket_date.year, month: bucket_date.month, cweek: bucket_date.cweek, total_profiles_created: bucket["doc_count"]}}
end

# subscriptions

%w(start silver gold).each do |plan|
  stats["total_active_#{plan}_subscriptions"] = client.count(index: :gigmit_production_subscriptions, body: {
    query: {
      filtered: {
        filter: {
          bool: {
            must: {
              term: {
                plan: plan
              }
            },
            should: [
              {range: {valid_until: {gte: 'now'}}},
              {missing: {field: 'valid_until'}}
            ]
          }
        }
      }
    }
  })['count']
end

stats["subscriptions_histogram"] = client.search(index: "gigmit_production_subscriptions", body: {
  aggs: {
    subscriptions_over_time: {
      date_histogram: {
        field: "created_at",
        interval: "week",
        min_doc_count: 0
      }
    }
  }
})["aggregations"]["subscriptions_over_time"]["buckets"].map{|bucket| bucket_date = Date.parse(bucket["key_as_string"]); {year: bucket_date.year, month: bucket_date.month, cweek: bucket_date.cweek, total_subscriptions_created: bucket["doc_count"]}}

# gigs

stats["gigs_histogram"] = client.search(index: "gigmit_production_gigs", body: {
  aggs: {
    gigs_over_time: {
      date_histogram: {
        field: "created_at",
        interval: "week",
        min_doc_count: 0
      }
    }
  }
})["aggregations"]["gigs_over_time"]["buckets"].map{|bucket| bucket_date = Date.parse(bucket["key_as_string"]); {year: bucket_date.year, month: bucket_date.month, cweek: bucket_date.cweek, total_gigs_created: bucket["doc_count"]}}

# bookings

# stats["bookings_histogram"] = client.search(index: "gigmit_production_contracts", body: {
#   query: {
#     filtered: {
#       filter: {
#         term: {state: 'accepted'}
#       }
#     }
#   },
#   aggs: {
#     bookings_over_time: {
#       date_histogram: {
#         field: "created_at",
#         interval: "week",
#         min_doc_count: 0
#       }
#     }
#   }
# })["aggregations"]["bookings_over_time"]["buckets"].map{|bucket| bucket_date = Date.parse(bucket["key_as_string"]); {year: bucket_date.year, month: bucket_date.month, cweek: bucket_date.cweek, total_bookings: bucket["doc_count"]}}

# require 'pry'; binding.pry

template    = File.read('./dashboard.haml')
haml_engine = Haml::Engine.new(template)
content     = haml_engine.render(Object.new, {stats: stats})

File.write('./index.html', content)
