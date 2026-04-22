enum ViewState<Value: Equatable>: Equatable {
    case loading
    case loaded(Value)
    case empty(message: String)
    case error(message: String)
}
