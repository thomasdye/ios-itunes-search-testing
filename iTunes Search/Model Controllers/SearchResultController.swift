//
//  SearchResultController.swift
//  iTunes Search
//
//  Created by Spencer Curtis on 8/5/18.
//  Copyright © 2018 Lambda School. All rights reserved.

import Foundation

protocol NetworkSessionProtocol {
    func fetch(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void)
}

// Producgion version of 'NetworkSessionProtocol'
extension URLSession: NetworkSessionProtocol {
    

    func fetch(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        
        let dataTask = self.dataTask(with: request,
                                     completionHandler: completionHandler)
        
        dataTask.resume()
    }
}

// Testing version of 'NetworkSessionProtocol'
class MockURLSession: NetworkSessionProtocol {
    
    let data: Data?
    let error: Error?
    init(data: Data?, error: Error?) {
        self.data = data
        self.error = error
    }
    
    func fetch(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        DispatchQueue.global().async {
            completionHandler(self.data, nil, self.error)
        }
    }
}

class SearchResultController {
    
    enum PerformSearchError: Error {
        case requestURLIsNil
        case network(Error)
        case invalidStateNoButNoDataEither
        case invalidJSON(Error)
    }
    
    func performSearch(for searchTerm: String,
                       resultType: ResultType,
                       urlSession: NetworkSessionProtocol,
                       completion: @escaping (Result<[SearchResult], PerformSearchError>) -> Void) {
        
        // Preparing the parameters for our URL request.
        var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        let parameters = ["term": searchTerm,
                          "entity": resultType.rawValue]
        
        // CompactMap -> transforms the individual elements of a collection into some other element type, while ignoring any options that return a nil value
        // (key, value) -> (URLQueryItem)
        let queryItems = parameters.compactMap { URLQueryItem(name: $0.key, value: $0.value) }
        urlComponents?.queryItems = queryItems
        
        // Prevent execution if 'requestURL' is nil
        guard let requestURL = urlComponents?.url else {
            return
                completion(.failure(.requestURLIsNil))
        }
        
        // 'requestURL' is not nil
        var request = URLRequest(url: requestURL)
        request.httpMethod = HTTPMethod.get.rawValue
        
        // Begin a network request to the iTunes API
        // What type is 'urlSession'?
        // WE don't know.
        // All we know is that it implements 'NetworkSessionProtocol'
        urlSession.fetch(with: request) { (possibleData, _, possibleError) in
            
            // We're in a background queue.
            // There are no networking errors
            guard possibleError == nil else {
                // We're done
                completion(.failure(.network(possibleError!)))
                return
            }
            
            // We did receive data from iTunes API
            guard let data = possibleData else {
                completion(.failure(.invalidStateNoButNoDataEither))
                return }
            
            do {
                // Decode the data we received into a JSON
                let jsonDecoder = JSONDecoder()
                let searchResults = try jsonDecoder.decode(SearchResults.self, from: data)
                completion(.success(searchResults.results))
            } catch {
                completion(.failure(.invalidJSON(error)))
            }
        }
    }
    
    let baseURL = URL(string: "https://itunes.apple.com/search")!
}
