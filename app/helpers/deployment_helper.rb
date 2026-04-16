module DeploymentHelper
  def gantt_color(outcome)
    case outcome.to_s
    when "exited" then "bg-signal-green"
    when "failed" then "bg-signal-red"
    else "bg-steel"
    end
  end

  def gantt_color_light(outcome)
    case outcome.to_s
    when "exited" then "bg-signal-green/20"
    when "failed" then "bg-signal-red/20"
    else "bg-steel/20"
    end
  end
end
