module VMC::App
  class Apps < Base
    def display_apps_table(apps)
      table(
        ["name", "infra", "status", "usage", v2? && "plan", "runtime", "urls", "services"],
        apps.collect { |a|
          [ c(a.name, :name),
            c(a.infra.name, :infra),
            app_status(a),
            "#{a.total_instances} x #{human_mb(a.memory)}",
            v2? && (a.production ? "prod" : "dev"),
            a.runtime.name,
            if a.urls.empty?
              d("none")
            elsif a.urls.size == 1
              a.url
            else
              a.urls.join(", ")
            end,
            if a.services.empty?
              d("none")
            else
              a.services.collect {|s| c(s.name, :name)}.join(", ")
            end
          ]
        })
    end
  end
end
