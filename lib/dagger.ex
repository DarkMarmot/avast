defmodule Dagger do
  alias Dagger.{Point, Instance}
  # Directed Acyclic Graph Event Repo
  require Logger

  defstruct instance: nil,
            # map of name to container (states, targets, views, actions)
            points: %{},
            ephemerals: MapSet.new(),
            # list of triggers to match events  to actions
            triggers: [],
            cyclic: false,
            # topological sort of targets
            sorted_targets: []

  def new(key \\ nil) do
    %Dagger{instance: Instance.new(key)}
  end

  def create(schema) do
    %Dagger{}
    |> define_states(Map.get(schema, :states, %{}))
    |> define_views(Map.get(schema, :views, %{}))
    |> define_targets(Map.get(schema, :targets, %{}))
    |> define_actions(Map.get(schema, :actions, %{}))
    |> define_effects(Map.get(schema, :effects, %{}))
    |> generate_outputs()
    |> note_ephemerals()
    |> sort_targets()

    # define all
    # THEN add outputs

    #    |> define_views(schema.views)

    #    |> define_triggers(schema.triggers)

    # todo add outputs to targets
    # sort targets
  end

  def note_ephemerals(%Dagger{points: points} = dagger) do
    ephemerals =
      points
      |> Enum.filter(fn {_k, v} -> v.ephemeral end)
      |> Enum.map(fn {k, _v} -> k end)
      |> MapSet.new()
    %Dagger{dagger | ephemerals: ephemerals}
  end

  def invoke_action(%Dagger{points: points} = dagger, name, value) do
    point = Map.get(points, name)

    source_values = resolve_sources(points, point.sources)
    action_and_source_values = source_values |> Map.put(name, value)

    updates =
      point.formula.(action_and_source_values)
      |> Enum.filter(fn {k, _v} -> get_type(points, k) == :state end)
      |> Map.new()
      |> Map.put(name, value)

    dagger |> update(updates)
  end

  def get_type(points, name) do
    point = Map.get(points, name)
    point.type
  end

  def define_actions(%Dagger{points: points} = dagger, actions) when is_map(actions) do
    new_points =
      actions
      |> Enum.reduce(
        points,
        fn {name, {formula, sources}}, acc ->
          action = Point.action(name, formula, sources)
          Map.put(acc, name, action)
        end
      )

    # todo verify: only output to states, all sources must exist, all outputs must be states

    %Dagger{dagger | points: new_points}
  end

  def define_states(%Dagger{points: points} = dagger, states) when is_list(states) do
    new_points =
      states
      |> Enum.reduce(
        points,
        fn name, acc ->
          point = Point.state(name)
          Map.put(acc, name, point)
        end
      )

    %Dagger{dagger | points: new_points}
  end

  def define_views(%Dagger{points: points} = dagger, %{} = views) do
    new_points =
      views
      |> Enum.reduce(
        points,
        fn {name, formula}, acc ->
          point = Point.view(name, formula)
          Map.put(acc, name, point)
        end
      )

    %Dagger{dagger | points: new_points}
  end

  def define_targets(%Dagger{points: points} = dagger, %{} = targets) do
    new_points =
      targets
      |> Enum.reduce(
        points,
        fn {name, {formula, sources}}, acc ->
          target = Point.target(name, formula, sources)
#          new_acc = acc |> add_outputs(name, sources)
          Map.put(acc, name, target)
        end
      )

    %Dagger{dagger | points: new_points}
  end

  def define_effects(%Dagger{points: points} = dagger, %{} = effects) do
    new_points =
      effects
      |> Enum.reduce(
           points,
           fn {name, {formula, sources}}, acc ->
             effect = Point.effect(name, formula, sources)
#             new_acc = acc |> add_outputs(name, sources)
             Map.put(acc, name, effect)
           end
         )

    %Dagger{dagger | points: new_points}
  end


  defp add_point(%Dagger{points: points} = dagger, %Point{name: name} = point) do
    assert_not_yet_defined(dagger, point)
    %Dagger{dagger | points: Map.put(points, name, point)}
  end

  defp assert_not_yet_defined(%Dagger{points: points} = dagger, %Point{name: name}) do
    if Map.has_key?(points, name) do
      raise("Dagger: Point #{inspect(name)} has already been defined!")
    end

    dagger
  end

  def sort_targets(%Dagger{} = dagger) do
    targets = get_targets(dagger)
    targets_by_name = Map.new(targets, fn t -> {t.name, t} end)

    {_visits, new_dagger} =
      Enum.reduce(targets, {MapSet.new(), dagger}, fn target, {visits, dagger} ->
        Logger.warn("sort: #{inspect(target)}")

        case MapSet.member?(visits, target.name) do
          false -> follow_outputs(target, targets_by_name, visits, MapSet.new(), dagger)
          true -> {visits, dagger}
        end
      end)

    new_dagger
  end

  defp follow_outputs(target, targets_by_name, visits, path, dagger) do
    Logger.warn("follow: #{inspect(target.name)}")

    new_visits = MapSet.put(visits, target.name)
    new_path = MapSet.put(path, target.name)

    {final_visits, new_dagger} =
      Enum.reduce(target.outputs, {new_visits, dagger}, fn output_name, {visits, dagger} ->
        cond do
          MapSet.member?(visits, output_name) == false and
              Map.has_key?(targets_by_name, output_name) ->
            output = Map.get(targets_by_name, output_name)
            follow_outputs(output, targets_by_name, visits, new_path, dagger)

          true ->
            {visits, dagger}
        end
      end)

    Logger.warn("inject: #{inspect(target.name)}")

    final_dagger = %Dagger{new_dagger | sorted_targets: [target.name | new_dagger.sorted_targets]}
    {final_visits, final_dagger}
  end

#  def trigger(
#        %Dagger{triggers: triggers} = dagger,
#        action,
#        filter \\ nil,
#        transform \\ nil,
#        continue \\ false
#      ) do
#    t = Trigger.new(action, filter, transform, continue)
#    %Dagger{dagger | triggers: [t | triggers]}
#  end


  def get_targets(%Dagger{points: points}) do
    points
    |> Map.values()
    |> Enum.filter(fn %Point{type: type} -> type == :target or type == :effect end)
  end

  def update(%Dagger{} = dagger, updates) when is_map(updates) do
    dagger
    |> update_states(updates)
    |> update_targets()
#    |> reset_ephemerals()
  end

  defp update_states(%Dagger{points: points} = dagger, updates) when is_map(updates) do
    new_points =
      updates
      |> Enum.reduce(
        points,
        fn {name, value}, acc ->
          point = Map.get(points, name)
          Map.put(acc, name, %Point{point | value: value, active: true})
        end
      )

    %Dagger{dagger | points: new_points}
  end

  def update_targets(%Dagger{points: points, sorted_targets: sorted_targets} = dagger) do
    Logger.warn("sorted targets: #{inspect(sorted_targets)}")

    new_points =
      sorted_targets
      |> Enum.reduce(
        points,
        fn target_name, acc ->
          target = Map.get(acc, target_name)
          can_update = are_all_sources_active?(acc, target.sources)

          new_target =
            case can_update do
              true -> update_target(acc, target)
              false -> target
            end

          Map.put(acc, target_name, new_target)
        end
      )

    %Dagger{dagger | points: new_points}
  end

  def reset_ephemerals(%Dagger{points: points, ephemerals: ephemerals} = dagger) do
    new_points =
      ephemerals
      |> Enum.reduce(
           points,
           fn name, acc ->
             point = Map.get(points, name)
             Map.put(acc, name, %Point{point | active: false})
           end
         )

    %Dagger{dagger | points: new_points}
  end

  def are_all_sources_active?(points, sources) do
    sources
    |> Enum.map(fn source_name -> Map.get(points, source_name) end)
    |> Enum.all?(fn point -> point.active end)
  end

  def update_target(%{} = points, %Point{sources: sources, formula: formula} = target) do
    value =
      points
      |> resolve_sources(sources)
      |> formula.()

    Logger.warn("activating #{target.name}")
    %Point{target | value: value, active: true}
  end

  def resolve_sources(%{} = points, sources) do
    r =
      sources
#      |> Enum.reject(fn source_name ->
#        point = Map.get(points, source_name)
#        point.ephemeral
#      end)
      |> Enum.reduce(
        %{},
        fn source_name, acc ->
          point = Map.get(points, source_name)
          value = resolve_source(point)
          Map.put(acc, source_name, value)
        end
      )

    Logger.warn("resolved: #{inspect(r)}")
    r
  end


  def resolve_source(%Point{type: :view, formula: formula}) do
    formula.()
  end

  def resolve_source(%Point{value: value}) do
    value
  end

  #  def process_event(%Dagger{triggers: triggers} = dagger, %Event{name: name} = event) do
  #    case Map.get(triggers, name, nil) do
  #      nil -> dagger # event not mapped
  #      action -> process_action(dagger, action, event)
  #    end
  #  end


  #  def define_trigger(%Dagger{} = dagger, name, action) do
  #    dagger |> register(name, :triggers, action)
  #  end

  def generate_outputs(%Dagger{points: points} = dagger) do
    new_points =
      points
      |> Enum.filter(fn {_k, v} -> v.type == :effect || v.type == :target end)
      |> Enum.map(fn {_k, v} -> v end)
      |> Enum.reduce(points, fn target, acc -> add_outputs(acc, target.name, target.sources) end)
      %Dagger{dagger | points: new_points}
  end

  def add_outputs(%{} = points, target_name, source_names) do
    Logger.warn("add outputs: #{inspect(target_name)} with #{inspect(source_names)}")

    source_names
    |> Enum.map(fn name ->
      Logger.warn("name #{inspect(name)}")
      p = Map.get(points, name)
      Logger.warn("point #{inspect(p)}")
      p
    end)
    |> Enum.filter(&(&1.type != :view))
    |> Enum.reduce(
      points,
      fn point, acc ->
        new_outputs = MapSet.put(point.outputs, target_name)
        new_source = %Point{point | outputs: new_outputs}
        Map.put(acc, point.name, new_source)
      end
    )
  end


  #
  #  def receive_event(%Event{} = event) do
  #    GenServer.call({:receive_event, event})
  #  end
  #
  #
  #  def handle_call({:receive_event, event}, _from, %Dagger{} = state) do
  #
  #    # event, handled by action, update states to targets to gen events
  #
  ##    new_state =
  ##      actions
  ##      |> Enum.filter(fn a -> Action.handles_event?(a, event) end)
  ##      |> Enum.reduce(state, fn a, s -> perform_action(a, event, s) end)
  #
  #    {:reply, :ok, state}
  #
  #  end



  def mult(x, y) do
    x * y
  end

  def sum(t) do
    t.prod + t.div
  end
end
