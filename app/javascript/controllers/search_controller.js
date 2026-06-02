import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["form", "input", "spinner", "dropdown"]

  connect() {
    this.selectedIndex = -1
    // Bind click outside event to close the dropdown
    this.clickOutsideHandler = this.closeDropdownOutside.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)

    // Autofocus input if on landing page
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  perform() {
    clearTimeout(this.timeout)

    const query = this.inputTarget.value.trim()
    if (query.length === 0) {
      this.hideDropdown()
      if (this.hasSpinnerTarget) {
        this.spinnerTarget.classList.add("opacity-0")
      }
      return
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("opacity-0")
    }

    // Set form to target typeahead frame for dynamic search suggestion loading
    this.formTarget.setAttribute("data-turbo-frame", "typeahead_results")

    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 250) // 250ms debounce
  }

  submit(event) {
    // If we're submitting via enter on input or button click (not automated typeahead perform)
    // we want to render in the main results container, not the typeahead dropdown
    const isTypeaheadSubmit = this.formTarget.getAttribute("data-turbo-frame") === "typeahead_results"
    
    if (!isTypeaheadSubmit) {
      this.formTarget.setAttribute("data-turbo-frame", "search_results")
      this.hideDropdown()
    }
  }

  finish(event) {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("opacity-0")
    }

    // If the request was for typeahead and we have a query, show the dropdown
    const isTypeahead = this.formTarget.getAttribute("data-turbo-frame") === "typeahead_results"
    const query = this.inputTarget.value.trim()

    if (isTypeahead && query.length > 0) {
      this.showDropdown()
    }
  }

  showDropdown() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.remove("hidden")
      this.selectedIndex = -1
      if (this.hasInputTarget) {
        this.inputTarget.setAttribute("aria-expanded", "true")
      }
    }
  }

  hideDropdown() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.add("hidden")
      this.selectedIndex = -1
      if (this.hasInputTarget) {
        this.inputTarget.setAttribute("aria-expanded", "false")
        this.inputTarget.removeAttribute("aria-activedescendant")
      }
    }
  }

  closeDropdownOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDropdown()
    }
  }

  closeDropdown() {
    this.hideDropdown()
  }

  navigateDown(event) {
    if (this.dropdownHidden) return

    event.preventDefault()
    const options = this.getOptions()
    if (options.length === 0) return

    this.selectedIndex = (this.selectedIndex + 1) % options.length
    this.highlightOption(options)
  }

  navigateUp(event) {
    if (this.dropdownHidden) return

    event.preventDefault()
    const options = this.getOptions()
    if (options.length === 0) return

    if (this.selectedIndex <= 0) {
      this.selectedIndex = options.length - 1
    } else {
      this.selectedIndex -= 1
    }
    this.highlightOption(options)
  }

  enterPressed(event) {
    // If the dropdown is visible and an item is selected, navigate to it instead of submitting form
    if (!this.dropdownHidden && this.selectedIndex >= 0) {
      const options = this.getOptions()
      const selectedOption = options[this.selectedIndex]
      if (selectedOption) {
        event.preventDefault()
        selectedOption.click()
        return
      }
    }

    // If no option is selected, perform normal submit to main search_results frame
    this.formTarget.setAttribute("data-turbo-frame", "search_results")
    this.hideDropdown()
    this.formTarget.requestSubmit()
  }

  get dropdownHidden() {
    return !this.hasDropdownTarget || this.dropdownTarget.classList.contains("hidden")
  }

  getOptions() {
    if (!this.hasDropdownTarget) return []
    return this.dropdownTarget.querySelectorAll("[data-typeahead-option]")
  }

  highlightOption(options) {
    options.forEach((opt, idx) => {
      if (idx === this.selectedIndex) {
        opt.classList.add("bg-indigo-50/60", "text-indigo-950")
        opt.setAttribute("aria-selected", "true")
        opt.scrollIntoView({ block: "nearest" })
        if (this.hasInputTarget) {
          this.inputTarget.setAttribute("aria-activedescendant", opt.id)
        }
      } else {
        opt.classList.remove("bg-indigo-50/60", "text-indigo-950")
        opt.setAttribute("aria-selected", "false")
      }
    })
  }
}
