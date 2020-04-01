defmodule OpenCensusElasticAPM.Reporter do
  @behaviour :oc_reporter
  defmodule State do
    defstruct apm_server: nil, metadata: nil
  end

  def init(_) do
    hostname = elem(:inet.gethostname(), 1) |> to_string()
    node_name = Application.get_env(:opencensus_elastic_apm, :node_name, "")
    pod_name = Application.get_env(:opencensus_elastic_apm, :pod_name, "")
    namespace = Application.get_env(:opencensus_elastic_apm, :namespace, "")
    pod_uid = Application.get_env(:opencensus_elastic_apm, :pod_uid, "")
    container_id = Application.get_env(:opencensus_elastic_apm, :container_id, "")
    service_name = Application.fetch_env!(:opencensus_elastic_apm, :service_name)
    apm_server = Application.fetch_env!(:opencensus_elastic_apm, :apm_server)

    metadata_json = %{
      metadata: %{
        process: %{
          pid: System.pid() |> String.to_integer(),
          title: "BEAM"
        },
        system: %{
          detected_hostname: hostname,
          platform: :os.type() |> elem(1) |> to_string(),
          container: %{id: container_id},
          kubernetes: %{
            namespace: namespace,
            pod: %{
              uid: pod_uid,
              name: pod_name
            },
            node: %{name: node_name}
          }
        },
        service: %{
          name: service_name,
          agent: %{
            name: "elixir",
            version: "0.1.0"
          },
          version: "0.0.0",
          environment: "test",
          language: %{name: "Elixir", version: System.version()},
          runtime: %{name: "OTP", version: System.otp_release()}
        }
      }
    }

    %State{metadata: metadata_json, apm_server: apm_server}
  end

  def report(spans, %State{metadata: metadata_json, apm_server: apm_server}) do
    encoded_spans =
      spans
      |> Enum.map(&Opencensus.Span.from/1)
      |> Enum.map(fn
        %Opencensus.Span{
          span_id: span_id,
          trace_id: trace_id,
          parent_span_id: undefined,
          name: name,
          start_time: start_time,
          end_time: end_time,
          attributes: attributes
        }
        when undefined in [nil, :undefined] ->
          %{
            transaction: %{
              name: name,
              type: "test_type",
              id: Opencensus.SpanContext.hex_span_id(span_id),
              trace_id: Opencensus.SpanContext.hex_trace_id(trace_id),
              parent_id: nil,
              span_count: %{started: length(spans) - 1, dropped: 0},
              timestamp: :wts.to_absolute(start_time),
              duration: :wts.duration(start_time, end_time) / 1000,
              context: %{
                tags: Map.delete(attributes, "entry")
              }
            }
          }

        %Opencensus.Span{
          span_id: span_id,
          trace_id: trace_id,
          parent_span_id: parent_span_id,
          name: name,
          start_time: start_time,
          end_time: end_time,
          attributes: attributes
        } ->
          if Map.get(attributes, "entry", false) do
            %{
              transaction: %{
                name: name,
                type: "test_type",
                id: Opencensus.SpanContext.hex_span_id(span_id),
                trace_id: Opencensus.SpanContext.hex_trace_id(trace_id),
                parent_id: Opencensus.SpanContext.hex_span_id(parent_span_id),
                span_count: %{started: 1, dropped: 0},
                timestamp: :wts.to_absolute(start_time),
                duration: :wts.duration(start_time, end_time) / 1000,
                context: %{
                  tags: Map.delete(attributes, "entry")
                }
              }
            }
          else
            %{
              span: %{
                type: "test_type",
                id: Opencensus.SpanContext.hex_span_id(span_id),
                trace_id: Opencensus.SpanContext.hex_trace_id(trace_id),
                parent_id: Opencensus.SpanContext.hex_span_id(parent_span_id),
                name: name,
                timestamp: :wts.to_absolute(start_time),
                duration: :wts.duration(start_time, end_time) / 1000,
                context: %{
                  tags: Map.delete(attributes, "entry")
                }
              }
            }
          end
      end)
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    HTTPoison.post(
      apm_server,
      Jason.encode!(metadata_json) <> "\n" <> encoded_spans,
      [{"Content-Type", "application/x-ndjson"}]
    )

    :ok
  end
end
