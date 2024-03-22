defmodule Phoenix.LiveViewTest.E2E.FormFeedbackLive do
  use Phoenix.LiveView, layout: {__MODULE__.Layout, :live}

  defmodule Layout do
    use Phoenix.Component

    def render("live.html", assigns) do
      ~H"""
      <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
      <script src="/assets/phoenix/phoenix.min.js"></script>
      <script src="/assets/phoenix_live_view/phoenix_live_view.js"></script>
      <script>
        const feedbackFor = (liveSocket) => {
          const PHX_FEEDBACK_FOR = "phx-feedback-for"
          const PHX_FEEDBACK_GROUP = "phx-feedback-group"
          const PHX_NO_FEEDBACK_CLASS = "phx-no-feedback"
          let feedbackContainers = []
          let inputPending = false
          let submitPending = false

          // helper functions
          function showError(inputEl){
            if(inputEl.name){
              let query = feedbackSelector(inputEl)
              document.querySelectorAll(query).forEach((el) => {
                liveSocket.addOrRemoveClasses(el, [], [PHX_NO_FEEDBACK_CLASS])
              })
            }
          }

          function isFeedbackContainer(el){
            return el.hasAttribute && el.hasAttribute(PHX_FEEDBACK_FOR)
          }

          function resetForm(form){
            Array.from(form.elements).forEach(input => {
              let query = feedbackSelector(input)
              document.querySelectorAll(query).forEach((feedbackEl) => {
                liveSocket.addOrRemoveClasses(feedbackEl, [PHX_NO_FEEDBACK_CLASS], [])
              })
            })
          }

          function maybeHideFeedback(feedbackContainers){
            // because we can have multiple containers with the same phxFeedbackFor value
            // we perform the check only once and store the result;
            // we often have multiple containers, because we push both fromEl and toEl in onBeforeElUpdated
            // when a container is updated
            const feedbackResults = {}
            feedbackContainers.forEach(el => {
              // skip elements that are not in the DOM
              if(!document.contains(el)) return
              const feedback = el.getAttribute(PHX_FEEDBACK_FOR)
              if(!feedback){
                // the container previously had phx-feedback-for, but now it doesn't
                // remove the class from the container (if it exists)
                liveSocket.addOrRemoveClasses(el, [], [PHX_NO_FEEDBACK_CLASS])
                return
              }
              if(feedbackResults[feedback] === true){
                hideFeedback(el)
                return
              }
              feedbackResults[feedback] = shouldHideFeedback(feedback, PHX_FEEDBACK_GROUP)
              if(feedbackResults[feedback] === true){
                hideFeedback(el)
              }
            })
          }

          function hideFeedback(el){
            liveSocket.addOrRemoveClasses(el, [PHX_NO_FEEDBACK_CLASS], [])
          }

          function shouldHideFeedback(nameOrGroup, phxFeedbackGroup){
            const query = `[name="${nameOrGroup}"],
                            [name="${nameOrGroup}[]"],
                            [${phxFeedbackGroup}="${nameOrGroup}"]`
            let interacted = false
            document.querySelectorAll(query).forEach((input) => {
              if(liveSocket.inputInteracted(input)){
                interacted = true
              }
            })
            return !interacted
          }

          function feedbackSelector(input){
            let query = `[${PHX_FEEDBACK_FOR}="${input.name}"],
                          [${PHX_FEEDBACK_FOR}="${input.name.replace(/\[\]$/, "")}"]`
            if(input.getAttribute(PHX_FEEDBACK_GROUP)){
              query += `,[${PHX_FEEDBACK_FOR}="${input.getAttribute(PHX_FEEDBACK_GROUP)}"]`
            }
            return query
          }

          const onBeforeElUpdated = (event) => {
            const {fromEl, toEl} = event.detail
            // mark both from and to els as feedback containers, as we don't know yet which one will be used
            // and we also need to remove the phx-no-feedback class when the phx-feedback-for attribute is removed
            if(isFeedbackContainer(fromEl) || isFeedbackContainer(toEl)){
              feedbackContainers.push(fromEl)
              feedbackContainers.push(toEl)
            }
          }

          const onNodeAdded = (event) => {
            const {el} = event.detail
            if(isFeedbackContainer(el)) feedbackContainers.push(el)
          }

          const onPatchStart = () => feedbackContainers = []
          const onPatchEnd = () => {
            if(inputPending){
              showError(inputPending)
              inputPending = null
            }
            if(submitPending){
              Array.from(submitPending.elements).forEach(input => showError(input))
              submitPending = null
            }
            maybeHideFeedback(feedbackContainers)
          }

          // we only want to update the feedback after the patch has been applied
          const onInput = (e) => inputPending = e.target
          const onSubmit = (e) => submitPending = e.target

          const onReset = (e) => resetForm(e.target)

          window.addEventListener("change", onInput)
          window.addEventListener("input", onInput)
          window.addEventListener("submit", onSubmit)
          window.addEventListener("reset", onReset)

          document.addEventListener("phx:update-start", onPatchStart)
          document.addEventListener("phx:update-end", onPatchEnd)
          document.addEventListener("phx:patch-before-el-updated", onBeforeElUpdated)
          document.addEventListener("phx:patch-node-added", onNodeAdded)
        }
        let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
        let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {params: {_csrf_token: csrfToken}})
        feedbackFor(liveSocket)
        liveSocket.connect()
        window.liveSocket = liveSocket
      </script>
      <style>
        * { font-size: 1.1em; }
      </style>
      <%= @inner_content %>
      """
    end
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0, submit_count: 0, validate_count: 0, feedback: true)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, :validate_count, socket.assigns.validate_count + 1)}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :submit_count, socket.assigns.submit_count + 1)}
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count - 1)}
  end

  def handle_event("toggle-feedback", _, socket) do
    {:noreply, assign(socket, :feedback, !socket.assigns.feedback)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <style>
      .phx-no-feedback {
        display: none;
      }
    </style>
    <p>Button Count: <%= @count %></p>
    <p>Validate Count: <%= @validate_count %></p>
    <p>Submit Count: <%= @submit_count %></p>
    <button phx-click="inc" class="bg-blue-500 text-white p-4">+</button>
    <button phx-click="dec" class="bg-blue-500 text-white p-4">-</button>

    <.myform />

    <div phx-feedback-for={@feedback && "myfeedback"} data-feedback-container>
      I am visible, because phx-no-feedback is not set for myfeedback!
    </div>

    <button phx-click="toggle-feedback">Toggle feedback</button>
    """
  end

  defp myform(assigns) do
    ~H"""
    <form id="myform" name="test" phx-change="validate" phx-submit="submit">
      <input type="text" name="name" class="border border-gray-500" placeholder="type sth" />

      <.other_input />

      <button type="submit">Submit</button>
      <button type="reset">Reset</button>
    </form>
    """
  end

  defp other_input(assigns) do
    ~H"""
    <input type="text" name="myfeedback" class="border border-gray-500" placeholder="myfeedback" />
    """
  end
end
