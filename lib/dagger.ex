defmodule Dagger do
  alias Dagger.{Point, Instance, Event, Trigger}
  # Directed Acyclic Graph Event Repo
  require Logger

  defstruct instance: nil,
            # map of name to container (states, targets, views, actions)
            points: %{},
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
    |> define_states(schema.states)
    |> define_views(schema.views)
    |> define_targets(schema.targets)
    |> define_actions(schema.actions)
    |> sort_targets()

    #    |> define_views(schema.views)

    #    |> define_triggers(schema.triggers)

    # todo add outputs to targets
    # sort targets
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

    # todo only output to states, all sources must exist, all outputs must be states

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
          new_acc = acc |> add_outputs(name, sources)
          Map.put(new_acc, name, target)
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

  def trigger(
        %Dagger{triggers: triggers} = dagger,
        action,
        filter \\ nil,
        transform \\ nil,
        continue \\ false
      ) do
    t = Trigger.new(action, filter, transform, continue)
    %Dagger{dagger | triggers: [t | triggers]}
  end

  #  def action(%Dagger{} = dagger, name, sources, outputs, formula) do
  #    p = Point.action(name, formula, sources, outputs)
  #
  #    dagger
  #    |> add_point(p)
  #  end
  #
  #  def state(%Dagger{} = dagger, name, value \\ nil) do
  #    p = Point.state(name, value)
  #
  #    dagger
  #    |> add_point(p)
  #  end
  #
  #  def view(%Dagger{} = dagger, name, sources, formula) when is_function(formula) do
  #    p = Point.view(name, formula, sources)
  #
  #    dagger
  #    |> add_point(p)
  #  end
  #
  #  def view(%Dagger{} = dagger, name, value) do
  #    p = Point.view(name, value)
  #
  #    dagger
  #    |> add_point(p)
  #  end
  #
  #  def target(%Dagger{} = dagger, name, sources, formula) do
  #    p = Point.target(name, formula, sources)
  #    Logger.error("ARGH")
  #    Logger.warn("make target #{name}")
  #    dagger
  #    |> add_point(p)
  #    |> add_outputs(name, sources)
  #  end

  def get_targets(%Dagger{points: points}) do
    points
    |> Map.values()
    |> Enum.filter(fn %Point{type: type} -> type == :target or type == :event end)
  end

  def update(%Dagger{} = dagger, updates) when is_map(updates) do
    dagger
    |> update_states(updates)
    |> update_targets()
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

    # make it change all points on each pass
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
      |> Enum.reject(fn source_name ->
        point = Map.get(points, source_name)
        point.ephemeral
      end)
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

  def resolve_source(%Point{type: :state, value: value}) do
    value
  end

  def resolve_source(%Point{type: :target, value: value}) do
    value
  end

  def resolve_source(%Point{type: :view, formula: formula}) do
    formula.()
  end

  #  def resolve_sources(%{} = points, sources) do
  #    sources
  #    |> Enum.map(
  #         fn source_name ->
  #           source = Map.get(points, source_name)
  #           {source_name, source.value}
  #         end)
  #  end

  #  def process_event(%Dagger{triggers: triggers} = dagger, %Event{name: name} = event) do
  #    case Map.get(triggers, name, nil) do
  #      nil -> dagger # event not mapped
  #      action -> process_action(dagger, action, event)
  #    end
  #  end

  #  def process_action(%Dagger{} = dagger, %Action{sources: sources, formula: formula} = action, values \\ %{}) do
  #
  #      updates =
  #        dagger
  #        |> resolve_sources(sources)
  #        |> Map.merge(values)
  #        |> formula.()
  #
  #      dagger
  #      |> update_states(updates)
  #      |> update_targets()
  #
  #  end

  #  def note_modifiers(%Dagger{modifiers_by_target: modifiers_by_target} = dagger, target_name, sources) do
  #
  #    reactive_sources = filter_reactive_sources(dagger, sources)
  #    modifiers =
  #      Map.get(modifiers_by_target, target_name, MapSet.new())
  #      |> MapSet.union(MapSet.new(reactive_sources))
  #
  #    dagger |> put_in([:modifiers_by_target, target_name], modifiers)
  #  end

  #  def update_targets(%Dagger{targets: targets, line_of_attack: line_of_attack} = dagger) do
  #
  #    line_of_attack
  #    |> Enum.reduce(targets,
  #         fn target_name, acc ->
  #           target = Map.get(targets, target_name)
  #           new_target = update_target(dagger, target)
  #           Map.put(acc, target_name, new_target)
  #         end)
  #
  #  end

  #  def define_trigger(%Dagger{} = dagger, name, action) do
  #    dagger |> register(name, :triggers, action)
  #  end

  #  defp update_dagger(%Dagger{} = dagger, path, value) do
  #    put_in(dagger, path |> Enum.map(&Access.key/1), value)
  #  end
  #
  #  defp update_element(%Dagger{} = dagger, element) do
  #    name = element.name
  #    category = Map.get(dagger.dictionary, name)
  #    update_dagger(dagger, [category, name], element)
  #  end

  #  def wire_outputs(points, target_name, source_names) do
  #    source_names
  #    |> Enum.reduce(
  #      points,
  #      fn source_name, acc ->
  #        source = Map.get(acc, source_name)
  #        new_outputs = MapSet.put(source.outputs, target_name)
  #        new_source = %Point{source | outputs: new_outputs}
  #        Map.put(points, source_name, new_source)
  #      end
  #    )
  #  end

  def add_outputs(%{} = points, target_name, source_names) do
    Logger.warn("add outputs: #{inspect(target_name)} with #{inspect(source_names)}")

    source_names
    |> Enum.map(fn name -> Map.get(points, name) end)
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

  #  def update_target(
  #        %Dagger{} = dagger,
  #        %Target{sources: sources, formula: formula, value: {current_value, _}} = target) do
  #
  #    source_values = resolve_source_values(dagger, sources)
  #    new_value = formula.(current_value, source_values)
  #    %Target{target | value: {new_value, current_value}, changed: new_value != current_value}
  #  end
  #
  #  def resolve_source_value(%Dagger{dictionary: dictionary} = dagger, name) do
  #    true = already_defined?(dagger, name)
  #    source_type = Map.get(dictionary, name)
  #    case source_type do
  #      :state -> resolve_state_value(dagger, name)
  #      :target -> resolve_target_value(dagger, name)
  #      :view -> resolve_view_value(dagger, name)
  #    end
  #  end
  #
  #  def resolve_state_value(%Dagger{states: states}, name) do
  #    %State{value: value} = Map.get(states, name)
  #    value
  #  end
  #
  #  def resolve_view_value(%Dagger{views: views}, name) do
  #    view_func = Map.get(views, name)
  #    view_func.()
  #  end
  #
  #  def resolve_sources(%Dagger{dictionary: dictionary} = dagger, sources) when is_list(sources) do
  #
  #  end
  #

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

  #  defp perform_action(action, event, state) do
  #
  #    use_map = resolve_use_values(action.use)
  #    change_map = action.transform.(event, use_map)
  #    # apply changes to states, pass -- every target gets {new_value, old_value} map
  #    # each target gets {current_map, prior_map}
  #  end
  #
  #  defp resolve_use_values(names) do
  #    %{}
  #  end

  def mult(x, y) do
    x * y
  end

  def sum(t) do
    t.prod + t.div
  end
end
